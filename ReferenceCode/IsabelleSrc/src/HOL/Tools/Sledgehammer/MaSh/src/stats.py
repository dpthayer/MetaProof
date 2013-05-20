#     Title:      HOL/Tools/Sledgehammer/MaSh/src/stats.py
#     Author:     Daniel Kuehlwein, ICIS, Radboud University Nijmegen
#     Copyright   2012
#
# Statistics collector.

'''
Created on Jul 9, 2012

@author: Daniel Kuehlwein
'''

import logging,string
from cPickle import load,dump

class Statistics(object):
    '''
    Class for all the statistics
    '''

    def __init__(self,cutOff=500):
        '''
        Constructor
        '''
        self.logger = logging.getLogger('Statistics')
        self.avgAUC = 0.0
        self.avgRecall100 = 0.0
        self.avgAvailable = 0.0
        self.avgDepNr = 0.0
        self.problems = 0.0
        self.cutOff = cutOff
        self.recallData = [0]*cutOff
        self.recall100Data = [0]*cutOff
        self.aucData = []
        self.premiseOccurenceCounter = {}
        self.firstDepAppearance = {}
        self.depAppearances = []

    def update(self,predictions,dependencies,statementCounter):
        """
        Evaluates AUC, dependencies, recall100 and number of available premises of a prediction.
        """
        available = len(predictions)
        predictions = predictions[:self.cutOff]
        dependencies = set(dependencies)
        # No Stats for if no dependencies
        if len(dependencies) == 0:
            self.logger.debug('No Dependencies for statement %s' % statementCounter )
            self.badPreds = []
            return
        if len(predictions) < self.cutOff:
            for i in range(len(predictions),self.cutOff):
                self.recall100Data[i] += 1
                self.recallData[i] += 1
        for d in dependencies:
            if self.premiseOccurenceCounter.has_key(d):
                self.premiseOccurenceCounter[d] += 1
            else:
                self.premiseOccurenceCounter[d] = 1
            if self.firstDepAppearance.has_key(d):
                self.depAppearances.append(statementCounter-self.firstDepAppearance[d])
            else:
                self.firstDepAppearance[d] = statementCounter
        depNr = len(dependencies)
        aucSum = 0.
        posResults = 0.
        positives, negatives = 0, 0
        recall100 = 0.0
        badPreds = []
        depsFound = []
        for index,pId in enumerate(predictions):
            if pId in dependencies:        #positive
                posResults+=1
                positives+=1
                recall100 = index+1
                depsFound.append(pId)
                if index > 200:
                    badPreds.append(pId)
            else:
                aucSum += posResults
                negatives+=1
            # Update Recall and Recall100 stats
            if depNr == positives:
                self.recall100Data[index] += 1
            if depNr == 0:
                self.recallData[index] += 1
            else:
                self.recallData[index] += float(positives)/depNr

        if not depNr == positives:
            depsFound = set(depsFound)
            missing = []
            for dep in dependencies:
                if not dep in depsFound:
                    missing.append(dep)
                    badPreds.append(dep)
                    recall100 = len(predictions)+1
                    positives+=1
            self.logger.debug('Dependencies missing for %s in accessibles! Estimating Statistics.',\
                              string.join([str(dep) for dep in missing],','))

        if positives == 0 or negatives == 0:
            auc = 1.0
        else:
            auc = aucSum/(negatives*positives)

        self.aucData.append(auc)
        self.avgAUC += auc
        self.avgRecall100 += recall100
        self.problems += 1
        self.badPreds = badPreds
        self.avgAvailable += available
        self.avgDepNr += depNr
        self.logger.info('Statement: %s: AUC: %s \t Needed: %s \t Recall100: %s \t Available: %s \t cutOff:%s',\
                          statementCounter,round(100*auc,2),depNr,recall100,available,self.cutOff)

    def printAvg(self):
        self.logger.info('Average results:')
        self.logger.info('avgAUC: %s \t avgDepNr: %s \t avgRecall100: %s \t cutOff:%s', \
                         round(100*self.avgAUC/self.problems,2),round(self.avgDepNr/self.problems,2),round(self.avgRecall100/self.problems,2),self.cutOff)

        #try:
        #if True:
        if False:
            from matplotlib.pyplot import plot,figure,show,xlabel,ylabel,axis,hist
            avgRecall = [float(x)/self.problems for x in self.recallData]
            figure('Recall')
            plot(range(self.cutOff),avgRecall)
            ylabel('Average Recall')
            xlabel('Highest ranked premises')
            axis([0,self.cutOff,0.0,1.0])
            figure('100%Recall')
            plot(range(self.cutOff),self.recall100Data)
            ylabel('100%Recall')
            xlabel('Highest ranked premises')
            axis([0,self.cutOff,0,self.problems])
            figure('AUC Histogram')
            hist(self.aucData,bins=100)
            ylabel('Problems')
            xlabel('AUC')
            maxCount = max(self.premiseOccurenceCounter.values())
            minCount = min(self.premiseOccurenceCounter.values())
            figure('Dependency Occurances')
            hist(self.premiseOccurenceCounter.values(),bins=range(minCount,maxCount+2),align = 'left')
            #ylabel('Occurences')
            xlabel('Number of Times a Dependency Occurs')
            figure('Dependency Appearance in Problems after Introduction.')
            hist(self.depAppearances,bins=50)
            figure('Dependency Appearance in Problems after Introduction in Percent.')
            xAxis = range(max(self.depAppearances)+1)
            yAxis = [0] * (max(self.depAppearances)+1)
            for val in self.depAppearances:
                yAxis[val] += 1
            yAxis = [float(x)/len(self.firstDepAppearance.keys()) for x in yAxis]
            plot(xAxis,yAxis)
            show()
        #except:
        #    self.logger.warning('Matplotlib module missing. Skipping graphs.')

    def save(self,fileName):
        oStream = open(fileName, 'wb')
        dump((self.avgAUC,self.avgRecall100,self.avgAvailable,self.avgDepNr,self.problems,self.cutOff,self.recallData,self.recall100Data,self.aucData,self.premiseOccurenceCounter),oStream)
        oStream.close()
    def load(self,fileName):
        iStream = open(fileName, 'rb')
        self.avgAUC,self.avgRecall100,self.avgAvailable,self.avgDepNr,self.problems,self.cutOff,self.recallData,self.recall100Data,self.aucData,self.premiseOccurenceCounter = load(iStream)
        iStream.close()

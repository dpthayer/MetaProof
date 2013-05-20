#     Title:      HOL/Tools/Sledgehammer/MaSh/src/sparseNaiveBayes.py
#     Author:     Daniel Kuehlwein, ICIS, Radboud University Nijmegen
#     Copyright   2012
#
# An updatable sparse naive Bayes classifier.

'''
Created on Jul 11, 2012

@author: Daniel Kuehlwein
'''

from cPickle import dump,load
from numpy import array
from math import log

class sparseNBClassifier(object):
    '''
    An updateable naive Bayes classifier.
    '''

    def __init__(self,defaultPriorWeight = 20.0,posWeight = 20.0,defVal = -15.0):
        '''
        Constructor
        '''
        self.counts = {}
        self.defaultPriorWeight = defaultPriorWeight
        self.posWeight = posWeight
        self.defVal = defVal

    def initializeModel(self,trainData,dicts):
        """
        Build basic model from training data.
        """
        for d in trainData:            
            dFeatureCounts = {}
            # Give p |- p a higher weight
            if not self.defaultPriorWeight == 0:            
                for f,_w in dicts.featureDict[d]:
                    dFeatureCounts[f] = self.defaultPriorWeight
            self.counts[d] = [self.defaultPriorWeight,dFeatureCounts]

        for key in dicts.dependenciesDict.keys():
            # Add p proves p
            keyDeps = [key]+dicts.dependenciesDict[key]
            for dep in keyDeps:
                self.counts[dep][0] += 1
                depFeatures = dicts.featureDict[key]
                for f,_w in depFeatures:
                    if self.counts[dep][1].has_key(f):
                        self.counts[dep][1][f] += 1
                    else:
                        self.counts[dep][1][f] = 1


    def update(self,dataPoint,features,dependencies):
        """
        Updates the Model.
        """
        if not self.counts.has_key(dataPoint):
            dFeatureCounts = {}            
            # Give p |- p a higher weight
            if not self.defaultPriorWeight == 0:               
                for f,_w in features:
                    dFeatureCounts[f] = self.defaultPriorWeight
            self.counts[dataPoint] = [self.defaultPriorWeight,dFeatureCounts]            
        for dep in dependencies:
            self.counts[dep][0] += 1
            for f,_w in features:
                if self.counts[dep][1].has_key(f):
                    self.counts[dep][1][f] += 1
                else:
                    self.counts[dep][1][f] = 1

    def delete(self,dataPoint,features,dependencies):
        """
        Deletes a single datapoint from the model.
        """
        for dep in dependencies:
            self.counts[dep][0] -= 1
            for f,_w in features:
                self.counts[dep][1][f] -= 1


    def overwrite(self,problemId,newDependencies,dicts):
        """
        Deletes the old dependencies of problemId and replaces them with the new ones. Updates the model accordingly.
        """
        assert self.counts.has_key(problemId)
        oldDeps = dicts.dependenciesDict[problemId]
        features = dicts.featureDict[problemId]
        self.delete(problemId,features,oldDeps)
        self.update(problemId,features,newDependencies)

    def predict(self,features,accessibles,dicts):
        """
        For each accessible, predicts the probability of it being useful given the features.
        Returns a ranking of the accessibles.
        """
        predictions = []
        for a in accessibles:
            posA = self.counts[a][0]
            fA = set(self.counts[a][1].keys())
            fWeightsA = self.counts[a][1]
            resultA = log(posA)
            for f,w in features:
                # DEBUG
                #w = 1
                if f in fA:
                    if fWeightsA[f] == 0:
                        resultA += w*self.defVal
                    else:
                        assert fWeightsA[f] <= posA
                        resultA += w*log(float(self.posWeight*fWeightsA[f])/posA)
                else:
                    resultA += w*self.defVal
            predictions.append(resultA)
        predictions = array(predictions)
        perm = (-predictions).argsort()
        return array(accessibles)[perm],predictions[perm]

    def save(self,fileName):
        OStream = open(fileName, 'wb')
        dump((self.counts,self.defaultPriorWeight,self.posWeight,self.defVal),OStream)
        OStream.close()

    def load(self,fileName):
        OStream = open(fileName, 'rb')
        self.counts,self.defaultPriorWeight,self.posWeight,self.defVal = load(OStream)
        OStream.close()


if __name__ == '__main__':
    featureDict = {0:[0,1,2],1:[3,2,1]}
    dependenciesDict = {0:[0],1:[0,1]}
    libDicts = (featureDict,dependenciesDict,{})
    c = sparseNBClassifier()
    c.initializeModel([0,1],libDicts)
    c.update(2,[14,1,3],[0,2])
    print c.counts
    print c.predict([0,14],[0,1,2])
    c.storeModel('x')
    d = sparseNBClassifier()
    d.loadModel('x')
    print c.counts
    print d.counts
    print 'Done'

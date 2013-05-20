This project is an effort to take the two great existing Logic Proof systems in existence and create a MetaSystem that incorporates the best of each in a single enterprize.  The intent is to create a set of protocol layers that create a seperation of concerns with well defined interfaces betyween them.

The layers are currently laid out as follows

Application Layer - this is where the logic for using the system for some pragmatic purpose resides

Session Layer - this is where the communications between a point of service and the logic engine is mediated

Syntax Layer - this is where a textual representation of a system is converted into a binary representation

Type Layer - this is the set of types that a syntactic representation is translated into.  This is where the semantics of the system resides.

Logic Layer - this is where the manipulations of the type system occurs that correspond to a specific system of logic

Proof and Certificate Layer - This is the repository of finished proofs and proof certificates and the system for managing libraries of such artifacts.





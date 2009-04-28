/*
Copyright (c) 2009 Noel R. Cower

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

#include <stdio.h>
#include <ffi/ffi.h>
#include <sys/mman.h>
#include <brl.mod/blitz.mod/blitz.h>

// this is a bad thing to do, don't copy this
typedef struct {
	BBObject obj;
	BBString* key;
	int indexed;
	union {
		int (*sets)(BBObject*,unsigned short	);
		int (*setb)(BBObject*,unsigned char		);
		int (*seti)(BBObject*,int				);
		int (*setl)(BBObject*,long long			);
		int (*setf)(BBObject*,float				);
		int (*setd)(BBObject*,double			);
		int (*seto)(BBObject*,BBObject*			);
		int (*setis)(BBObject*,unsigned short,int);
		int (*setib)(BBObject*,unsigned char ,int);
		int (*setii)(BBObject*,int			 ,int);
		int (*setil)(BBObject*,long long	 ,int);
		int (*setif)(BBObject*,float		 ,int);
		int (*setid)(BBObject*,double		 ,int);
		int (*setio)(BBObject*,BBObject*	 ,int);
	};
	/*
	// NOTE: commented out until getter closures are added
	union {
		unsigned short	 (*gets)(BBObject*);
		unsigned char	 (*getb)(BBObject*);
		int				 (*geti)(BBObject*);
		long long		 (*getl)(BBObject*);
		float			 (*getf)(BBObject*);
		double			 (*getd)(BBObject*);
		BBObject*		 (*geto)(BBObject*);
	};
	*/
	BBObject* type;
#ifdef THREADED
	BBObject* lock;
#endif
} bbTObserver;


// TODO: if placed in a module, CHANGE THESE.
#ifdef THREADED
extern int _bb_TObserver_Lock(BBObject*);
extern int _bb_TObserver_Unlock(BBObject*);
#endif

extern int bb_WillChangeValueForKey(BBObject*,BBString*);
extern int bb_DidChangeValueForKey(BBObject*,BBString*);


// reflection junk
extern BBObject *brl_reflection_ByteTypeId, *brl_reflection_ShortTypeId,
	*brl_reflection_IntTypeId, *brl_reflection_LongTypeId,
	*brl_reflection_FloatTypeId, *brl_reflection_DoubleTypeId;


// handy macro for laziness
#define TypeId(X) (brl_reflection_##X##TypeId)

// This was originally written in BMax, but I hate working with pointers in
// BMax, so now it's written in C.	Isn't that just awesome!?
static void autoObserverSetter(ffi_cif* cif, void* result, void** args, void* userdata) {
	bbTObserver* observer = (bbTObserver*)userdata;
	
	#ifdef THREADED
	__bb_TObserver_Unlock(observer);
	#endif
	
	BBObject* self = *((BBObject**)(args[0]));
	void* arg1 = ((void*)(args[0]))+4;
	
    BBString* indexedKey = NULL;
	
	BBObject* typeid = observer->type;
	
	if ( observer->indexed )
	{
        int index;
        char indexer[16];
        
		if ( typeid == TypeId(Int)) {
            index = *(int*)(arg1+4);
            indexedKey = bbStringConcat(observer->key,
                            bbStringFromBytes(indexer,snprintf(indexer, 16, "[%i]", index)));
            bb_WillChangeValueForKey(self, indexedKey);
			*(int*)result = observer->setii(self, *(int*)arg1, index);
		} else if ( typeid == TypeId(Float) ) {
		    index = *(int*)(arg1+4);
            indexedKey = bbStringConcat(observer->key,
                            bbStringFromBytes(indexer,snprintf(indexer, 16, "[%i]", index)));
            bb_WillChangeValueForKey(self, indexedKey);
			*(int*)result = observer->setif(self, *(float*)arg1, index);
		} else if ( typeid == TypeId(Double) ) {
		    index = *(int*)(arg1+8);
            indexedKey = bbStringConcat(observer->key,
                            bbStringFromBytes(indexer,snprintf(indexer, 16, "[%i]", index)));
            bb_WillChangeValueForKey(self, indexedKey);
			*(int*)result = observer->setid(self, *(double*)arg1, index);
		} else if ( typeid == TypeId(Short) ) {
		    index = *(int*)(arg1+2);
            indexedKey = bbStringConcat(observer->key,
                            bbStringFromBytes(indexer,snprintf(indexer, 16, "[%i]", index)));
            bb_WillChangeValueForKey(self, indexedKey);
			*(int*)result = observer->setis(self, *(unsigned short*)arg1, index);
		} else if ( typeid == TypeId(Byte) ) {
		    index = *(int*)(arg1+1);
            indexedKey = bbStringConcat(observer->key,
                            bbStringFromBytes(indexer,snprintf(indexer, 16, "[%i]", index)));
            bb_WillChangeValueForKey(self, indexedKey);
			*(int*)result = observer->setib(self, *(unsigned char*)arg1, index);
		} else if ( typeid == TypeId(Long) ) {
		    index = *(int*)(arg1+8);
            indexedKey = bbStringConcat(observer->key,
                            bbStringFromBytes(indexer,snprintf(indexer, 16, "[%i]", index)));
            bb_WillChangeValueForKey(self, indexedKey);
			*(int*)result = observer->setil(self, *(long long*)arg1, index);
		} else {
		    index = *(int*)(arg1+4);
            indexedKey = bbStringConcat(observer->key,
                            bbStringFromBytes(indexer,snprintf(indexer, 16, "[%i]", index)));
            bb_WillChangeValueForKey(self, indexedKey);
			*(int*)result = observer->setio(self, *(BBObject**)arg1, index);
		}
	}
	else
	{
	    bb_WillChangeValueForKey(self, observer->key);
	    
		if ( typeid == TypeId(Int))
			*(int*)result = observer->seti(self, *(int*)arg1);
		else if ( typeid == TypeId(Float) )
			*(int*)result = observer->setf(self, *(float*)arg1);
		else if ( typeid == TypeId(Double) )
			*(int*)result = observer->setd(self, *(double*)arg1);
		else if ( typeid == TypeId(Short) )
			*(int*)result = observer->sets(self, *(unsigned short*)arg1);
		else if ( typeid == TypeId(Byte) )
			*(int*)result = observer->setb(self, *(unsigned char*)arg1);
		else if ( typeid == TypeId(Long) )
			*(int*)result = observer->setl(self, *(long long*)arg1);
		else
			*(int*)result = observer->seto(self, *(BBObject**)arg1);
	}
	
	#ifdef THREADED
	__bb_TObserver_Unlock(observer);
	#endif
	
	bb_DidChangeValueForKey(self, (indexedKey == NULL ? observer->key : indexedKey));
}

// Generates a setter closure for the observer.
ffi_closure* setterForObserverMethod(bbTObserver* observer)
{
	ffi_status status;
	ffi_cif *cif;
	ffi_closure *closure;
	int numargs = (observer->indexed ? 3 : 2);
	ffi_type *args[3] = {&ffi_type_pointer, NULL, &ffi_type_sint32};
	ffi_type *returnType;
	
	cif = (ffi_cif*)malloc(sizeof(ffi_cif));
	if ( cif == NULL )
		return NULL;
	
	BBObject* typeid = observer->type;
	if ( typeid == TypeId(Int) )
		args[1] = &ffi_type_sint32;
	else if ( typeid == TypeId(Float) )
		args[1] = &ffi_type_float;
	else if ( typeid == TypeId(Double) )
		args[1] = &ffi_type_double;
	else if ( typeid == TypeId(Short) )
		args[1] = &ffi_type_uint16;
	else if ( typeid == TypeId(Byte) )
		args[1] = &ffi_type_uint8;
	else if ( typeid == TypeId(Long) )
		args[1] = &ffi_type_sint64;
	else
		args[1] = &ffi_type_pointer;
	
	status = ffi_prep_cif(cif, FFI_DEFAULT_ABI, numargs, &ffi_type_sint32, args);
	
	if ( status != FFI_OK ) {
		fprintf(stderr, "ERROR: Failed to create ffi_cif\n");
		free(cif);
		return NULL;
	}
	
	closure = mmap(NULL, sizeof(ffi_closure),
		PROT_READ|PROT_WRITE, MAP_ANON|MAP_PRIVATE, -1, 0);
	
	if ( closure == (void*)-1 ) {
		fprintf(stderr, "ERROR: Failed to map ffi_closure\n");
		free(cif);
		return NULL;
	}
	
	status = ffi_prep_closure(closure, cif, &autoObserverSetter, observer);
	
	if (status == FFI_OK)
	{
		if ( mprotect(closure, sizeof(closure), PROT_READ|PROT_EXEC) == 0 )
		{
			BBRETAIN(&observer->obj);
			return closure;
		}
		else
		{
			fprintf(stderr, "ERROR: Failed to set closure's protection\n");
		}
	}
	
	fprintf(stderr, "ERROR: Failed to create closure\n");
	if ( munmap(closure, sizeof(ffi_closure)) != 0 )
		fprintf(stderr, "ERROR: Failed to unmap ffi_closure\n");
	
	free(cif);
	
	return NULL;
}

#ifdef THREADS

// Generates a getter closure for the observer.
ffi_closure* getterForObserverMethod(
	BBObject* observer, ffi_type *type,
	void(*fun)(ffi_cif*, void*, void**, void*))
{
	// TODO: code to create a getter closure that locks access to the key
	// (only applied to fields with some metadata set, e.g., synchronized)
	
	// NOTE: recursive lock - this code only applies to threaded builds anyway
	return NULL;
}

#endif

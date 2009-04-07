/**
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
**/

#include <brl.mod/blitz.mod/blitz.h>
#include <pub.mod/lua.mod/lua-5.1.4/src/lua.h>

// Create a block of memory and store a pointer to the object in it.
void lref_pushrawobject(lua_State* state, BBObject* obj) {
    BBRETAIN(obj);
    BBObject** data = (BBObject**)lua_newuserdata(state, sizeof(BBObject*));
    *data = obj;
}

// Decrease the ref count of an object inside of a userdata and set the userdata to point to a null object.
// Raises an error if the value pointed to by idx isn't a BBObject.  If a null object, does nothing.
void lref_releaserawobject(lua_State* state, int idx) {
    BBObject** data = (BBObject**)lua_touserdata(state, idx);
    
    if ( data == NULL )
        luaL_error(state, "lref_releaserawobject: Value at index %i is not a userdata", idx);
    
    if ( *data == &bbNullObject )
        return;         // do nothing
    
    BBRELEASE(*data);
    *data = &bbNullObject;
}

// Retrieve an object from a userdata.
BBObject* lref_torawobject(lua_State* state, int idx) {    
    BBObject** data = (BBObject**)lua_touserdata(state, idx);
    
    if ( data == NULL )
        return &bbNullObject;
    
    return *data;
}

// INTERNAL
// Used for Lua's `__gc' metatable method
int lref_disposeobject(lua_State* state) {
    if ( lua_gettop(state) != 1 ) {
        lua_pushstring(state, "lref_disposeobject: Invalid number of arguments to lref_disposeobject");
        lua_error(state);
    }
    
    lref_releaserawobject(state, -1);
    printf("Releasing object\n");
    
    return 0;
}

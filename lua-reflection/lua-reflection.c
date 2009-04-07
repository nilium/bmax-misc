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

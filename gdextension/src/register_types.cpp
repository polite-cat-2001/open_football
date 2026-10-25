#include "match_node.h"
#include "gpf_runtime_node.h"
#include "procedural_pitch.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_open_football_gdext(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
    
    UtilityFunctions::print("Initializing OpenFootball GDExtension");
    GDREGISTER_CLASS(MatchNode);
    GDREGISTER_CLASS(GpfRuntimeNode);
}

void uninitialize_open_football_gdext(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
    
    UtilityFunctions::print("Uninitializing OpenFootball GDExtension");
}

extern "C" {
    GDExtensionBool GDE_EXPORT open_football_gdext_init(
        GDExtensionInterfaceGetProcAddress p_get_proc_address,
        GDExtensionClassLibraryPtr p_library,
        GDExtensionInitialization *r_initialization
    ) {
        GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
        
        init_obj.register_initializer(initialize_open_football_gdext);
        init_obj.register_terminator(uninitialize_open_football_gdext);
        init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
        
        return init_obj.init();
    }
}

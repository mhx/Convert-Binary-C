
enum name_type { undefined, typename, identifier, enum_const };
enum decl_type { name_space_decl, struct_decl };

typedef struct {
    char *name;
    enum name_type type;
    enum decl_type decl_type;
    int scope_level;

}declaration;



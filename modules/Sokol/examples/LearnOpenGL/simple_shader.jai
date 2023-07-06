ATTR_vs_position :: 0;

simple_shader_desc :: () -> sg_shader_desc {
    desc: sg_shader_desc;
    desc.label = "simple_shader";
    desc.attrs[0].name = "position";

    desc.vs.entry  = "main";
    desc.vs.source = SIMPLE_VERTEX_SHADER;

    desc.fs.entry  = "main";
    desc.fs.source = SIMPLE_FRAGMENT_SHADER;

    return desc;
}

SIMPLE_VERTEX_SHADER :: #string END_VERTEX
#version 330

layout(location = 0) in vec4 position;

void main()
{
   gl_Position = vec4(position.x, position.y, position.z, 1.0);
}
END_VERTEX;


SIMPLE_FRAGMENT_SHADER :: #string END_FRAGMENT
#version 330

layout(location = 0) out vec4 FragColor;

void main()
{
    FragColor = vec4(0.65, 0.5, 0.5, 1.0);
}
END_FRAGMENT;
#if TOOLS
using Godot;

[Tool]
public partial class Initializer : EditorPlugin
{
	private EditorContextMenuPlugin script;
	
	public override void _EnterTree()
	{
		script = new FoldersCreator();
		AddContextMenuPlugin(EditorContextMenuPlugin.ContextMenuSlot.Filesystem,script);
	}
	public override void _ExitTree()
	{
		base._ExitTree();
		
		if(IsInstanceValid(script)) RemoveContextMenuPlugin(script);
	}
}
#endif

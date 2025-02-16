#if TOOLS
using Godot;

[Tool]
public partial class FoldersCreator : EditorContextMenuPlugin
{
	public override void _PopupMenu(string[] paths)
	{
		//Texture2D texture = GD.Load<Texture2D>("res://addons/FoldersCreator/Icon.png");
		Callable callable = new Callable(this, MethodName.AddFolders);
		AddContextMenuItem("Add default folders",callable/*,texture*/);
	}

	public void AddFolders(Variant args)
	{
		DirAccess.MakeDirRecursiveAbsolute("res://Scripts");
		DirAccess.MakeDirRecursiveAbsolute("res://Data");
		DirAccess.MakeDirRecursiveAbsolute("res://Settings");
		
		DirAccess.MakeDirRecursiveAbsolute("res://Art/Models");
		DirAccess.MakeDirRecursiveAbsolute("res://Art/Textures");
		DirAccess.MakeDirRecursiveAbsolute("res://Art/Materials");
		DirAccess.MakeDirRecursiveAbsolute("res://Art/Prefabs");
		DirAccess.MakeDirRecursiveAbsolute("res://Art/VFX");
		DirAccess.MakeDirRecursiveAbsolute("res://Art/SFX");
		
		EditorInterface.Singleton.GetResourceFilesystem().Scan();
	}
}
#endif
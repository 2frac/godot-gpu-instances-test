@tool
extends EditorPlugin


var ext = null

func _enter_tree() -> void:
	if not ext:
		ext = GLTFMultimeshes.new()
	
	GLTFDocument.register_gltf_document_extension(ext)


func _exit_tree() -> void:
	if ext:
		GLTFDocument.unregister_gltf_document_extension(ext)
		ext = null  # for editing. and its stateless anyway.

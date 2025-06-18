@tool
extends GLTFDocumentExtension
class_name GLTFMultimeshes 


func process_gpu_instancing(state: GLTFState, gltf_node: GLTFNode, json: Dictionary, node: Node):
	# TODO option to skipping bad transforms instead of return
	
	var extensions = json.get('extensions', {})
	if not extensions:
		return

	var gpu_instancing = extensions.get('EXT_mesh_gpu_instancing')
	if not gpu_instancing:
		return
	
	var accessors = state.get_accessors()

	var buffer_views = state.get_buffer_views()
	var attributes = gpu_instancing.get('attributes')
	
	var translation = null
	var rotation = null
	var scale = null
	
	var instance_count = 0
	
	var translation_index = attributes.get('TRANSLATION')
	if translation_index:
		var accessor = accessors[translation_index]
		if accessor.accessor_type != accessor.TYPE_VEC3:
			push_error('bad translation accessor_type: %s ' % accessor.accessor_type)
			return ERR_INVALID_DATA
		if accessor.component_type != accessor.COMPONENT_TYPE_SINGLE_FLOAT:
			print("NOT FLOAT 1")
			
		var buffer_view = buffer_views[translation_index]
		var buffer_bytes = buffer_view.load_buffer_view_data(state)
		translation = buffer_bytes.to_vector3_array()
		instance_count = translation.size()
	
	var rotation_index = attributes.get('ROTATION')
	if rotation_index:
		var accessor = accessors[rotation_index]
		if accessor.accessor_type != accessor.TYPE_VEC4:
			push_error('bad rotation accessor_type: %s ' % accessor.accessor_type)
			return ERR_INVALID_DATA
		if accessor.component_type != accessor.COMPONENT_TYPE_SINGLE_FLOAT:
			push_error('bad rotation component_type: %s ' % accessor.component_type)
			return ERR_INVALID_DATA
		
		var buffer_view = buffer_views[rotation_index]
		var buffer_bytes = buffer_view.load_buffer_view_data(state)
		rotation = buffer_bytes.to_vector4_array()
		if instance_count and instance_count != rotation.size():
			push_error('bad instance count: %s!=%s' % [instance_count, rotation.size()])
			return ERR_INVALID_DATA
		instance_count = rotation.size()
	
	var scale_index = attributes.get('SCALE')
	if scale_index:
		var accessor = accessors[scale_index]
		if accessor.accessor_type != accessor.TYPE_VEC3:
			push_error('bad scale accessor_type: %s ' % accessor.accessor_type)
			return ERR_INVALID_DATA
		if accessor.component_type != accessor.COMPONENT_TYPE_SINGLE_FLOAT:
			print("NOT FLOAT")  # TODO adjust
		
		var buffer_view = buffer_views[scale_index]
		var buffer_bytes = buffer_view.load_buffer_view_data(state)
		scale = buffer_bytes.to_vector3_array()
		if instance_count and instance_count != scale.size():
			push_error('bad instance count: %s!=%s' % [instance_count, scale.size()])
			return ERR_INVALID_DATA
		instance_count = scale.size()
	
	if not instance_count:
		# might still create empty one? 
		# or of size=1 with single identity transform.
		return
		
	var multimesh = MultiMesh.new()
	
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = instance_count
	
	for i in instance_count:
		var tr = Transform3D()
		
		if translation != null:
			tr = tr.translated(translation[i])
		
		if rotation != null:
			var rot = rotation[i] as Vector4
			var quat = Quaternion(rot.x, rot.y, rot.z, rot.w)
			tr = tr * Transform3D(Basis(quat), Vector3.ZERO) 
			
		if scale != null:
			tr = tr.scaled(scale[i])
		
		multimesh.set_instance_transform(i, tr)
	
	# for late process?
	#if node is MeshInstance3D:
	#   multimesh.mesh = node.mesh
	if node is ImporterMeshInstance3D:
		multimesh.mesh = node.mesh.get_mesh()
	else: 
		print('unknown mesh node?')
		return ERR_INVALID_DATA
	
	var new_node = MultiMeshInstance3D.new()
	new_node.multimesh = multimesh
	new_node.name = node.name
	new_node.position = node.position
	new_node.rotation = node.rotation
	new_node.scale = node.scale
	
	node.replace_by(new_node, true)
	
	return OK


func process_multimesh_from_gn(node):
	var transforms = []
	var instance_nodes = []
	
	var mesh = null
	for child: Node3D in node.get_children():
		if child.name.begins_with('GN Instance'):
			if not mesh:
				var imp_mesh = child.mesh as ImporterMesh
				mesh = imp_mesh.get_mesh()
			
			transforms.append(child.transform)
			instance_nodes.append(child)
	
	if len(transforms):  # might want to create it anyway. 
		var new_node = MultiMeshInstance3D.new()
		var multimesh = MultiMesh.new()
		multimesh.mesh = mesh
		
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.instance_count = len(transforms)
		for i in range(len(transforms)):
			multimesh.set_instance_transform(i, transforms[i])
		
		new_node.multimesh = multimesh
		new_node.name = node.name
		new_node.position = node.position
		new_node.rotation = node.rotation
		new_node.scale = node.scale
		
		node.replace_by(new_node, true)  
		
		for child in instance_nodes:
			child.free()


func _import_node(state: GLTFState, gltf_node: GLTFNode, json: Dictionary, node: Node) -> Error:
	var accessors = state.get_accessors()
	if not node:  # probably deleted GN-instance
		return OK
		
	var extensions = json.get('extensions', {})
	if extensions:
		var res = process_gpu_instancing(state, gltf_node, json, node)
		if res != OK:
			return res
	
	if false and node.name.ends_with('-multimesh'):  # maybe other suffix to avoid potential collisions
		process_multimesh_from_gn(node)
	
	return OK

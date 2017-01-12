local env = {}
setmetatable(env, {__index = _G})
_ENV = env

local uecore = require("ue_core")

function read_fs(fs)
	local wchar_len = x.rint32(fs+4)
	if wchar_len>0 then
		local wchar_addr = x.rint32(fs)
		if wchar_addr~=0 then
			return x.rwstr(wchar_addr)
		end
	end
end

function write_fs(fs, str)
	local wchar_addr = x.rint32(fs)
	if wchar_addr~=0 then
		x.wwstr(x.rint32(fs), str)
		x.wint32(fs+4, string.len(str)+1)
	end
end

function enum_props(inst)
	local result=nil
	local decode_item=nil
	local decode_struct=nil
	
	function decode_prop_item(addr, prop, prefix, postfix)
		if addr~=0 and prop~=0 then
			local item={}
			local offset = uecore.get_prop_offset(prop)
			local type_name = uecore.get_obj_type_name(prop)
			item.name = uecore.get_obj_name(prop)
			if prefix then item.name = prefix..item.name end
			if postfix then item.name = item.name..postfix end
			item.prop = prop
			item.addr = addr+offset
			item.type = type_name
			
			if type_name=="Int64Property" or type_name=="UInt64Property" then
				item.value = x.rint64(item.addr)
				table.insert(result, item)
			elseif type_name=="DoubleProperty" then
				item.value = x.rdouble(item.addr)
				table.insert(result, item)
			elseif type_name=="NameProperty" then
				item.value = uecore.get_fname_name(item.addr)
				table.insert(result, item)
			elseif type_name=="IntProperty" or type_name=="UInt32Property" or type_name=="ObjectProperty" or type_name=="ClassProperty" then
				item.value = x.rint32(item.addr)
				table.insert(result, item)
			elseif type_name=="FloatProperty" then
				item.value = x.rfloat(item.addr)
				table.insert(result, item)
			elseif type_name=="Int16Property" or type_name=="UInt16Property" then
				item.value = x.rint16(item.addr)
				table.insert(result, item)
			elseif type_name=="UInt8Property" or type_name=="ByteProperty" then
				item.value = x.rint8(item.addr)
				table.insert(result, item)
			elseif type_name=="BoolProperty" then
				item.value = uecore.get_bool_prop_value(prop, item.addr)
				table.insert(result, item)
			elseif type_name=="StrProperty" then
				local fs = read_fs(item.addr)
				if fs then
					item.value=fs
				else
					item.value=""
				end
				table.insert(result, item)
			elseif type_name=="ArrayProperty" then
				local item_prop=uecore.get_prop_array(prop)
				local totalsize = uecore.get_prop_elem_size(prop)
				local itemsize = uecore.get_prop_elem_size(item_prop)
				local count = totalsize/itemsize
				for i=0, count-1, 1 do
					decode_prop_item(item.addr+i*itemsize, item_prop, nil, "["..i.."]")
				end
			elseif type_name=="StructProperty" then
				decode_struct(addr, uecore.get_prop_struct(prop), item.name..".", nil)
			else
				--print("undecode "..item.name..":"..item.type)
				item=nil
			end
		end
	end

	function recurse_decode_struct(addr, struct, prefix, postfix)
		local props = uecore.get_class_props(struct)
		for _, prop in pairs(props) do
			decode_item(addr, prop, prefix, postfix)
		end
	end

	result={}
	decode_item = decode_prop_item
	decode_struct = recurse_decode_struct
	
	local super = uecore.get_super_class(uecore.get_obj_type(inst))
	for _, class in pairs(super) do
		decode_struct(inst, class, nil, nil)
	end
	
	return result
end

function find_prop(inst, prop_name)
	local result = enum_props(inst)
	for _, item in pairs(result) do
		if string.find(item.name, prop_name) then
			return item
		end
	end
end

function set_prop(inst, prop_name, value)
	local item = find_prop(inst, prop_name)
	if item then
		local type_name = item.type

		if type_name=="Int64Property" or type_name=="UInt64Property" or type_name=="NameProperty" then
			x.wint64(item.addr, value)
		elseif type_name=="DoubleProperty" then
			item.value = x.wdouble(item.addr, value)
		elseif type_name=="IntProperty" or type_name=="UInt32Property" or type_name=="ObjectProperty" or type_name=="ClassProperty" then
			x.wint32(item.addr, value)
		elseif type_name=="FloatProperty" then
			x.wfloat(item.addr, value)
		elseif type_name=="Int16Property" or type_name=="UInt16Property" then
			x.wint16(item.addr, value)
		elseif type_name=="UInt8Property" or type_name=="ByteProperty" then
			x.wint8(item.addr, value)
		elseif type_name=="BoolProperty" then
			uecore.set_bool_prop_value(item.prop, item.addr, value)
		elseif type_name=="StrProperty" then
			write_fs(item.addr, value)
		end
	end
end

function get_inst(class)
	return uecore.get_class_inst(class)
end

function nameof(obj)
	return uecore.get_obj_name(obj)
end

function typeof(obj)
	return uecore.get_obj_type(obj)
end

function typenameof(obj)
	return uecore.get_obj_type_name(obj)
end

return env
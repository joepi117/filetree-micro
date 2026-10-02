VERSION = "1.0.0"

local micro = import("micro")
local config = import("micro/config")
local buffer = import("micro/buffer")
local shell = import("micro/shell")
local os = import("os")
local filepath = import("path/filepath")
local ioutil = import("io/ioutil")

local tree_view = nil
local line_to_path = {}
local current_dir = ""

-- Returns a listing of everything in the current working directory
local function build_listing(dir)
	line_to_path = {}
	local lines = {}

	local entries, err = ioutil.ReadDir(dir)
	if err ~= nil then
		micro.InfoBar():Error("filetree: cannot read" .. dir)
		return ""
	end

	for i = 1, #entries do
		local e = entries[i]
		if e:isDir() then
			table.insert(lines, e:Name() .. "/")
			table.insert(line_to_path, filepath.Join(dir, e:Name()))
		end
	end

	for i = 1, #entries do
		local e = entries[i]
		if not e:isDir() then
			table.insert(lines, e:Name())
			table.insert(line_to_path, filepath.Join(dir, e:Name()))
		end
	end
	return table.concat(lines, "\n")
end

-- Returns true if path is a directory
local function is_dir(path)
	local file_info, stat_error = os.Stat(path)
	if file_info ~= nil then
		return file_info:IsDir()
	else
		micro.InfoBar():Error("Error check if is dir: ", stat_error)
		return nil
	end
end

function render(dir)
	current_dir = dir
	local text = build_listing(dir)
	tree_view.Buf.EventHandler:Remove(tree_view.Buf:Start(), tree_view.Buf:End())
	tree_view.Buf.EventHandler:Insert(buffer.Loc(0, 0), text)
end

-- Open item at the selected position
function open_selected(bp)
	if bp ~= tree_view then
		bp:InsertNewline()
		return
	end

	local path = line_to_path[bp.Cursor.Loc.Y + 1]
	
	if path == nil then
		return
	end

	if is_dir(path) then
		render(path)
		return
	end

	bp:NextSplit()
	micro.CurPane():OpenCmd({path})
end

-- Opens the filetree
function open_filetree(bp)
	local cwd = os.Getwd()
	local text = build_listing(cwd)
	
	local buf = buffer.NewBuffer(text, "filetree")

	tree_view = bp:VSplitIndex(buf, false)

	tree_view.Buf:SetOptionNative("softwrap", false)
	tree_view.Buf:SetOptionNative("ruler", false)
	tree_view.Buf:SetOptionNative("scrollbar", false)
	tree_view.Buf.Type.Readonly = true
	tree_view:ResizePane(30)
end

-- Closes the filetree
function close_filetree()
	if tree_view ~= nil then
		tree_view:Quit()
		tree_view = nil
	end
end

-- Opens the filetree if its closed and vice versa
function toggle_filetree(bp)
	if tree_view == nil then
		open_filetree(bp)
	else 
		close_filetree()
	end
end

function init()
	config.MakeCommand("filetree", toggle_filetree, config.NoComplete)
	config.TryBindKey("Enter", "lua:filetree.open_selected", true)
end

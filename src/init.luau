--!strict
--!native
-- https://gist.github.com/MrChickenRocket/6c6ca8795822172f051eb98c088a7264
-- Services
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Packages
-- Modules
-- Types

-- Constants
local URL = "http://localhost:3090/"
local BYTES = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

-- private functions
function toB64(data: string): string
	return (
		(data:gsub(".", function(x: string): string
			local r, b = "", x:byte()
			for i = 8, 1, -1 do
				r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and "1" or "0")
			end
			return r
		end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
			if #x < 6 then
				return ""
			end
			local c = 0
			for i = 1, 6 do
				c = c + (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0)
			end
			return BYTES:sub(c + 1, c + 1)
		end) .. ({ "", "==", "=" })[#data % 3 + 1]
	)
end

function fromB64(data: string): string
	local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	data = string.gsub(data, "[^" .. b .. "=]", "")
	return (
		data:gsub(".", function(x)
			if x == "=" then
				return ""
			end
			local i = b:find(x)
			assert(i)
			local r, f = "", (i - 1)
			for j = 6, 1, -1 do
				r = r .. (f % 2 ^ j - f % 2 ^ (j - 1) > 0 and "1" or "0")
			end
			return r
		end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x: string): string
			if #x ~= 8 then
				return ""
			end
			local c = 0
			for i = 1, 8 do
				c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0)
			end
			return string.char(c)
		end)
	)
end

-- Class
local FileUtil = {}

FileUtil.Path = {}

function FileUtil.Path.split(path: string): (string, string)
	local items = path:split("/")
	local tail = items[#items]
	items[#items] = nil
	return table.concat(items, "/"), tail
end

function FileUtil.Path.splitExtension(path: string): (string, string)
	local items = path:split(".")
	local ext = items[#items]
	items[#items] = nil
	return table.concat(items, "."), "."..ext
end

function FileUtil.Path.getIfExists(path: string): boolean
	assert(RunService:IsStudio(), `this FileUtil function is studio-only`)
	local success, response = pcall(function()
		return HttpService:GetAsync(`{URL}?operation=exists&path={path}`)
	end)
	if success then
		return response == "true"
	else
		error(`Failed to get existence for {path}: ` .. tostring(response))
	end
end

function FileUtil.Path.getAbsolute(path: string): string
	assert(RunService:IsStudio(), `this FileUtil function is studio-only`)
	local success, response = pcall(function()
		return HttpService:GetAsync(`{URL}?operation=abspath&path={path}`)
	end)
	if success then
		return fromB64(response)
	else
		error(`Failed to get abspath for {path}: ` .. tostring(response))
	end
end

function FileUtil.makeDirectories(path: string): ()
	assert(RunService:IsStudio(), `this FileUtil function is studio-only`)
	local success, response = pcall(function()
		return HttpService:GetAsync(`{URL}?operation=mkdirs&path={path}`)
	end)
	if not success then
		error("Failed to make directories: " .. response)
	end
end

function FileUtil.run(command: string): string
	assert(RunService:IsStudio(), `this FileUtil function is studio-only`)
	local success, response = pcall(function()
		return HttpService:PostAsync(
			`{URL}?operation=run`,
			command
		)
	end)
	if success then
		return fromB64(response)
	else
		error("Failed to run command: " .. response)
	end
end

function FileUtil.remove(path: string): ()
	assert(RunService:IsStudio(), `this FileUtil function is studio-only`)
	local success, response = pcall(function()

		return HttpService:PostAsync(
			`{URL}?operation=remove&path={path}`,
			""
		)
	end)

	if not success then
		error("Failed to remove file: " .. response)
		return nil
	end
end


function FileUtil.append(path: string, content: string): ()
	assert(RunService:IsStudio(), `this FileUtil function is studio-only`)
	local chunks = {}
	local chunkSize = 512 * 1024 -- 512 KB
	local chunksCount = math.ceil(#content / chunkSize)

	for i = 1, chunksCount do
		local start = (i - 1) * chunkSize + 1
		local finish = i * chunkSize
		chunks[i] = content:sub(start, finish)
	end
	for i = 1, chunksCount do
		-- Encoded chunk should be sent as raw data (you might need to adjust your function `to_base64` to handle this)
		local chunkData = toB64(chunks[i])
		-- Additional information about chunk can be sent via URL parameters
		local success, response = pcall(function()
			return HttpService:PostAsync(
				`{URL}?operation=append&path={path}&index={i}&total={chunksCount}`,
				chunkData
			)
		end)

		if not success then
			error("Failed to append file: " .. response)
			return nil
		end
	end
end


function FileUtil.list(path: string): {[number]: string}
	assert(RunService:IsStudio(), `this FileUtil function is studio-only`)
	local success, response = pcall(function()
		return HttpService:GetAsync(`{URL}?operation=list&path={path}`)
	end)
	if success then
		local struct = HttpService:JSONDecode(response)
		local dir = {}
		for key,value in struct do
			local res = fromB64(value)
			table.insert(dir, res)
		end

		return dir
	else
		error(`Failed to list directory at {path}: ` .. tostring(response))
	end
end

function FileUtil.read(path: string)
	assert(RunService:IsStudio(), `this FileUtil function is studio-only`)
	local success, response = pcall(function()
		return HttpService:GetAsync(`{URL}?operation=read&path={path}`)
	end)
	if success then
		-- print("res: ", response)
		return fromB64(response)
	else
		error("Failed to read file: " .. tostring(response))
	end
end

function FileUtil.write(path: string, content: string): ()
	assert(RunService:IsStudio(), `this FileUtil function is studio-only`)
	local chunks = {}
	local chunkSize = 512 * 1024 -- 512 KB
	local chunksCount = math.ceil(#content / chunkSize)

	for i = 1, chunksCount do
		local start = (i - 1) * chunkSize + 1
		local finish = i * chunkSize
		chunks[i] = content:sub(start, finish)
	end
	for i = 1, chunksCount do
		-- Encoded chunk should be sent as raw data (you might need to adjust your function `to_base64` to handle this)
		local chunkData = toB64(chunks[i])
		-- Additional information about chunk can be sent via URL parameters
		local success, response = pcall(function()
			return HttpService:PostAsync(
				`{URL}?operation=write&path={path}&index={i}&total={chunksCount}`,
				chunkData
			)
		end)

		if not success then
			error("Failed to write file: " .. response)
		end
	end
end

return FileUtil

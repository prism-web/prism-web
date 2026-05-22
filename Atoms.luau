local HttpService = game:GetService("HttpService")
-- [[ Atom Parsing ]]
-- > Atoms.luau
-- This module is responsible for reading all atomic data and converting it
-- into legible tables to pass onto Player.luau.

local Atoms = {}
local utils = require("../utils")

-- Simple utility function to read the atom headers.
function Atoms.ReadAtom(videoBuffer, atom)
	return {
		Size = utils.read_u32_be(videoBuffer, atom),
		Type = utils.readAtomType(videoBuffer, atom + 4),
	}
end

-- Reading a full file
function Atoms.GetAtoms(videoBuffer, startPin, limit)
	local pin = startPin or 0
	limit = limit or buffer.len(videoBuffer)

	local atoms = {}

	while pin + 8 < limit do
		local atom = Atoms.ReadAtom(videoBuffer, pin)
		print(atom.Type)
		Atoms.ParseAtom(videoBuffer, pin)

		table.insert(atoms, { videoBuffer, pin })

		if atom.Size <= 0 then
			return atoms
		end

		if pin + atom.Size > limit then
			return atoms
		end

		pin = pin + atom.Size
	end
	return atoms
end

local parseMethods = {

	-- mvhd: Movie header atom
	-- Provides metadata about the video.
	-- Will help us with displaying video information.
	mvhd = function(videoBuffer, atom)
		Atoms.ReadAtom(videoBuffer, atom)

		local version = buffer.readi8(videoBuffer, atom + 8)
		local flags = utils.read_u24_be(videoBuffer, atom + 9)

		local creationTime
		local modificationTime
		local timescale
		local duration

		-- Two versions of mvhd.
		-- Version 2 is optimized and uses less bytes.
		if version == 1 then
			creationTime = utils.read_u64_be(videoBuffer, atom + 12)
			modificationTime = utils.read_u64_be(videoBuffer, atom + 20)
			timescale = utils.read_u32_be(videoBuffer, atom + 28)
			duration = utils.read_u64_be(videoBuffer, atom + 32)
		else
			creationTime = utils.read_u32_be(videoBuffer, atom + 12)
			modificationTime = utils.read_u32_be(videoBuffer, atom + 16)
			timescale = utils.read_u32_be(videoBuffer, atom + 20)
			duration = utils.read_u32_be(videoBuffer, atom + 24)
		end

		return {
			Version = version, -- mvhd version
			Flags = flags, -- Any flags (usually empty)
			CreationTime = creationTime, -- The time when the video was created (seconds since epoch)
			ModificationTime = modificationTime, -- The time when the video was modified (seconds since epoch)
			TimeScale = timescale, -- Amount of time units per second. Usually 1,000.
			Duration = duration, -- Length of the movie (in timescale)
		}
	end,

	-- moov: Movie atom
	-- Includes more technical metadata to help us parse the video.
	-- Contains: trak
	moov = function(videoBuffer, atom)
		local read = Atoms.ReadAtom(videoBuffer, atom)
		return Atoms.GetAtoms(videoBuffer, atom + 8, atom + read.Size)
	end,

	-- trak: Movie track atom
	-- A whole track of the video (video, subtitles, audio, etc)
	-- Contains: tkhd, mdia
	trak = function(videoBuffer, atom)
		local read = Atoms.ReadAtom(videoBuffer, atom)
		return Atoms.GetAtoms(videoBuffer, atom + 8, atom + read.Size)
	end,

	-- tkhd: Track header atom
	-- Metadata for a single track.
	tkhd = function(videoBuffer, atom)
		local version = buffer.readi8(videoBuffer, atom + 8)
		local flags = utils.read_u24_be(videoBuffer, atom + 9)

		local trackId
		local duration

		-- Two versions are present for tkhd.
		-- Version 2 uses less bytes.
		if version == 1 then
			trackId = utils.read_u32_be(videoBuffer, atom + 28)
			duration = utils.read_u64_be(videoBuffer, atom + 36)
		else
			trackId = utils.read_u32_be(videoBuffer, atom + 20)
			duration = utils.read_u32_be(videoBuffer, atom + 28)
		end

		return {
			Version = version, -- tkhd version
			Flags = flags, -- Any flags (usually empty)
			TrackId = trackId, -- Track ID
			Duration = duration, -- Duration of this track (in timescale)
		}
	end,

	-- stopped commenting here

	mdia = function(videoBuffer, atom)
		local read = Atoms.ReadAtom(videoBuffer, atom)
		return Atoms.GetAtoms(videoBuffer, atom + 8, atom + read.Size)
	end,

	mdhd = function(videoBuffer, atom)
		local version = buffer.readi8(videoBuffer, atom + 8)
		local flags = utils.read_u24_be(videoBuffer, atom + 9)

		local timescale
		local duration

		if version == 1 then
			timescale = utils.read_u32_be(videoBuffer, atom + 28)
			duration = utils.read_u64_be(videoBuffer, atom + 32)
		else
			timescale = utils.read_u32_be(videoBuffer, atom + 20)
			duration = utils.read_u32_be(videoBuffer, atom + 24)
		end

		return {
			Version = version,
			Flags = flags,
			TimeScale = timescale,
			Duration = duration,
		}
	end,

	hdlr = function(videoBuffer, atom)
		local handlerType = utils.readAtomType(videoBuffer, atom + 16)

		return {
			HandlerType = handlerType,
		}
	end,

	minf = function(videoBuffer, atom)
		local read = Atoms.ReadAtom(videoBuffer, atom)
		return Atoms.GetAtoms(videoBuffer, atom + 8, atom + read.Size)
	end,

	stbl = function(videoBuffer, atom)
		local read = Atoms.ReadAtom(videoBuffer, atom)
		return Atoms.GetAtoms(videoBuffer, atom + 8, atom + read.Size)
	end,

	stsd = function(videoBuffer, atom)
		local entryCount = utils.read_u32_be(videoBuffer, atom + 12)

		return {
			EntryCount = entryCount,
		}
	end,

	stts = function(videoBuffer, atom)
		local entryCount = utils.read_u32_be(videoBuffer, atom + 12)

		return {
			EntryCount = entryCount,
		}
	end,

	stsc = function(videoBuffer, atom)
		local entryCount = utils.read_u32_be(videoBuffer, atom + 12)

		return {
			EntryCount = entryCount,
		}
	end,

	-- stsz: Media data sample size identifier.
	-- TODO: Using stsz for decompression.
	stsz = function(videoBuffer, atom)
		local sampleSize = utils.read_u32_be(videoBuffer, atom + 12)
		local sampleCount = utils.read_u32_be(videoBuffer, atom + 16)

		return {
			SampleSize = sampleSize,
			SampleCount = sampleCount,
		}
	end,

	-- stco: Media data chunk identifier.
	-- TODO: Using stco for decompression.
	stco = function(videoBuffer, atom)
		local entryCount = utils.read_u32_be(videoBuffer, atom + 12)

		return {
			EntryCount = entryCount,
		}
	end,

	-- free: Empty space, nothing needed.
	free = function(videoBuffer, atom)
		return true
	end,

	-- skip: Empty space, nothing needed.
	skip = function(videoBuffer, atom)
		return true
	end,

	-- mdat: Holds all audio and video data
	-- We need nothing from the actual header other than an indication of what it is because GetAtoms will read its children anyway.
	mdat = function(videoBuffer, atom)
		local read = Atoms.ReadAtom(videoBuffer, atom)

		return {
			Size = read.Size,
		}
	end,
}

function Atoms.ParseAtom(videoBuffer: buffer, atom: number)
	local read = Atoms.ReadAtom(videoBuffer, atom)

	if parseMethods[read.Type] then
		return parseMethods[read.Type](videoBuffer, atom)
	end

	return nil
end

function Atoms.Test(url: string)
	local video = HttpService:GetAsync(url)
	local dataBuffer = buffer.fromstring(video)
	Atoms.GetAtoms(dataBuffer)
end

return Atoms

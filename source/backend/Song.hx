package backend;

import haxe.Json;
import lime.utils.Assets;
import objects.Note;
import sys.io.File;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>; // will only store loaded sections
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;
	var offset:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var format:String;

	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;
	
	@:optional var disableNoteRGB:Bool;
	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;

	@:optional var sectionIndex:Array<Int>; // for lazy loading
}

typedef SwagSection =
{
	var sectionNotes:Array<Dynamic>;
	var sectionBeats:Null<Float>;
	var mustHitSection:Bool;
	@:optional var altAnim:Bool;
	@:optional var gfSection:Bool;
	@:optional var bpm:Null<Float>;
	@:optional var changeBPM:Bool;
}

class Song
{
	public static var chartPath:String;
	public static var loadedSongName:String;

	// cache last loaded sections
	static var sectionCache:haxe.ds.IntMap<SwagSection> = new haxe.ds.IntMap();
	static var MAX_CACHE:Int = 20;

	// ====================
	// Lazy parse JSON
	public static function parseJSONLazy(path:String):SwagSong
	{
		var raw:String = File.getContent(path); // metadata + maybe small chunk
		var songJson:SwagSong = cast Json.parse(raw);

		if(songJson.notes != null) {
			songJson.sectionIndex = [];
			for(i in 0...songJson.notes.length)
				songJson.sectionIndex.push(i); // placeholder for future offsets
			songJson.notes = null; // free memory
		}

		return songJson;
	}

	// ====================
	// Load a single section on demand
	public static function loadSection(song:SwagSong, sectionNum:Int):SwagSection
	{
		if(sectionCache.exists(sectionNum))
			return sectionCache.get(sectionNum);

		// Read file again, parse only the section
		var raw:String = File.getContent(chartPath);
		var sections:Array<Dynamic> = Json.parse(raw).notes;
		var sec:SwagSection = cast sections[sectionNum];

		if(song.notes == null) song.notes = [];
		while(song.notes.length <= sectionNum) song.notes.push(null);
		song.notes[sectionNum] = sec;

		// Cache it
		sectionCache.set(sectionNum, sec);
		if(sectionCache.keys().length > MAX_CACHE)
			sectionCache.remove(sectionCache.keys()[0]);

		return sec;
	}

	// ====================
	// Load chart metadata only
	public static function loadFromJson(jsonInput:String):SwagSong
	{
		var formattedPath = Paths.formatToSongPath(jsonInput);
		chartPath = Paths.json(formattedPath);
		var song:SwagSong = parseJSONLazy(chartPath);
		loadedSongName = jsonInput;
		return song;
	}
}

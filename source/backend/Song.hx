package backend;

import haxe.Json;
import lime.utils.Assets;
import objects.Note;
import sys.io.File;
import haxe.ds.IntMap;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
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
	public var song:String;
	public var notes:Array<SwagSection>;
	public var events:Array<Dynamic>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var arrowSkin:String;
	public var splashSkin:String;
	public var gameOverChar:String;
	public var gameOverSound:String;
	public var gameOverLoop:String;
	public var gameOverEnd:String;
	public var disableNoteRGB:Bool = false;
	public var speed:Float = 1;
	public var stage:String;
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';
	public var format:String = 'psych_v1';

	// ====================
	// Static fields
	public static var chartPath:String;
	public static var loadedSongName:String;

	// Section cache for lazy loading
	static var sectionCache:IntMap<SwagSection> = new IntMap();
	static var MAX_CACHE:Int = 20;

	// ====================
	// Full chart conversion (old charts -> psych_v1)
	public static function convert(songJson:Dynamic):Void
	{
		if(songJson.gfVersion == null)
		{
			songJson.gfVersion = songJson.player3;
			if(Reflect.hasField(songJson, 'player3')) Reflect.deleteField(songJson, 'player3');
		}

		if(songJson.events == null)
		{
			songJson.events = [];
			for(secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];
				var i:Int = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;
				while(i < len)
				{
					var note:Array<Dynamic> = notes[i];
					if(note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else i++;
				}
			}
		}

		for(section in songJson.notes)
		{
			if(section.sectionBeats == null || Math.isNaN(section.sectionBeats))
				section.sectionBeats = 4;

			for(note in section.sectionNotes)
			{
				var gottaHitNote:Bool = (note[1] < 4) ? section.mustHitSection : !section.mustHitSection;
				note[1] = (note[1] % 4) + (gottaHitNote ? 0 : 4);

				if(note[3] != null && !Std.isOfType(note[3], String))
					note[3] = Note.defaultNoteTypes[note[3]];
			}
		}
	}

	// ====================
	// Load metadata only (lazy)
	public static function parseJSONLazy(path:String):SwagSong
	{
		var raw:String = File.getContent(path);
		var songJson:SwagSong = cast Json.parse(raw);

		if(songJson.notes != null)
		{
			songJson.sectionIndex = [];
			for(i in 0...songJson.notes.length)
				songJson.sectionIndex.push(i);
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

		var raw:String = File.getContent(chartPath);
		var sections:Array<Dynamic> = Json.parse(raw).notes;
		var sec:SwagSection = cast sections[sectionNum];

		if(song.notes == null) song.notes = [];
		while(song.notes.length <= sectionNum) song.notes.push(null);
		song.notes[sectionNum] = sec;

		sectionCache.set(sectionNum, sec);
		if(sectionCache.keys().iterator().hasNext() && sectionCache.keys().iterator().next() > MAX_CACHE)
			sectionCache.remove(sectionCache.keys().iterator().next());

		return sec;
	}

	// ====================
	// Original parseJSON method (kept for compatibility)
	public static function parseJSON(rawData:String, ?nameForError:String = null, ?convertTo:String = 'psych_v1'):SwagSong
	{
		var songJson:SwagSong = cast Json.parse(rawData);
		if(Reflect.hasField(songJson, 'song'))
		{
			var subSong:SwagSong = Reflect.field(songJson, 'song');
			if(subSong != null && Type.typeof(subSong) == TObject)
				songJson = subSong;
		}

		if(convertTo != null && convertTo.length > 0)
		{
			var fmt:String = songJson.format;
			if(fmt == null) fmt = songJson.format = 'unknown';

			switch(convertTo)
			{
				case 'psych_v1':
					if(!fmt.startsWith('psych_v1'))
					{
						trace('converting chart $nameForError with format $fmt to psych_v1 format...');
						songJson.format = 'psych_v1_convert';
						convert(songJson);
					}
			}
		}
		return songJson;
	}

	// ====================
	// Original getChart method (kept for compatibility)
	public static function getChart(jsonInput:String, ?folder:String):SwagSong
	{
		if(folder == null) folder = jsonInput;
		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);
		chartPath = Paths.json('$formattedFolder/$formattedSong');

		var rawData:String = File.getContent(chartPath);
		return rawData != null ? parseJSON(rawData, jsonInput) : null;
	}

	// ====================
	// Original loadFromJson (kept for compatibility)
	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		if(folder == null) folder = jsonInput;
		PlayState.SONG = getChart(jsonInput, folder);
		loadedSongName = folder;
		StageData.loadDirectory(PlayState.SONG);
		return PlayState.SONG;
	}
}

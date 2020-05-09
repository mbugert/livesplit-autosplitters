/* 
	Pro Pinball Big Race USA auto splitter
	Written by mbugert, https://github.com/mbugert/livesplit-autosplitters

	Features:
		- splits when entering/leaving cities and starting/ending missions
		- can split for several predefined score milestones
		- pauses timer during bonus count phases

	Some remaining ideas / todos:
		- find a way to start the timer automatically:
			- maybe via the number of balls in play?
				- target balls to respawn seems to be 0x4AEBB0 -> for example, is set to 4 in a 4-Passenger Frenzy, but stays 4 for much longer (in the city, on the road) after draining 3 of the 4 balls
				- number of balls drawn on screen: 0x492310, 0x4AE69C -> doesn't count balls in scoops -> useless
		- support Really Big Race Win
		- pause or do something else while players 2-4 are on
*/

state("BigRaceUSA", "v1.20b")
{
	uint music_track : 0xAEB5C;

	long p1_score : 0xAD414;
	long p1_money : 0xAD480;
}
state("BigRaceUSA", "v1.18")
{
	uint music_track : 0xAEB5C;

	long p1_score : 0xAD414;
	long p1_money : 0xAD480;

	// these work but are unused
	//long p2_score : 0xAD778;
	//long p2_money : 0xAD7E4;
	//long p3_money : 0xADB48;
	//long p4_money : 0xADEAC;	
}
state("BigRaceUSA", "v1.00")
{
	uint music_track : 0xAAB0C;

	long p1_score : 0xA9404;
	long p1_money : 0xA946C;
}

startup
{
	Action<string> DebugOutput = (text) => {
		print("[BRUSA Autosplitter] " + text);
	};
	vars.DebugOutput = DebugOutput;

	// big race win splits
	settings.Add("BigRace", true, "Category: Big Race Win");
	settings.SetToolTip("BigRace", "Splits on the way towards winning the Big Race");

	settings.CurrentDefaultParent = "BigRace";
	settings.Add("SplitEnterCities", true, "Split when entering cities");
	settings.Add("SplitExitCities", true, "Split when exiting cities");
	settings.Add("SplitCityMissions", false, "Split when starting/finishing city missions");
	settings.Add("SplitBigRaceStart", true, "Split when Big Race mission starts in SF");
	settings.Add("SplitBigRaceEnd", true, "Split when Big Race mission ends in NY");
	settings.CurrentDefaultParent = null;

	// score splits
	settings.Add("Score", false, "Category: Score Attack");
	settings.SetToolTip("Score", "Split when reaching certain amount of points");

	settings.CurrentDefaultParent = "Score";
	settings.Add("250M", true, "250M");
	settings.Add("500M", true, "500M");
	settings.Add("750M", true, "750M");
	settings.Add("1.000M", true, "1.000M");
	settings.Add("1.250M", false, "1.250M");
	settings.Add("1.500M", false, "1.500M");
	settings.CurrentDefaultParent = null;

	vars.playerState = 0;	// PLAYER_CITY_PRE_MISSION
}

init {
	int moduleSize = modules.First().ModuleMemorySize;
	if (moduleSize == 970752)
	{
		version = "v1.00";
	}
	else if (moduleSize == 991232)
	{
		// v1.18 and v1.20b have the same module size, so we check the version string shown in the ingame credits
		version = "v" + memory.ReadString(modules.First().BaseAddress + 0x7D328, 16);
	}
}

update
{
	// check split on music transitions
	if (settings["BigRace"] && old.music_track != current.music_track) {
		return true;
	}

	// check split on score changes
	if (settings["Score"] && old.p1_score != current.p1_score) {
		return true;
	}

	return false;
}

split
{
	// Values are the same as in the music test in the operator's menu minus 1.
	const uint M_AT_A_CITY = 2;
	const uint M_QUICKSHOT = 3;
	const uint M_CAR_WASH = 4;
	const uint M_CAR_PARK = 5;
	const uint M_CREATURE = 6;
	const uint M_ALIEN = 7;
	const uint M_SPEED_HUMPS = 8;
	const uint M_TAXI_RANK = 9;
	const uint M_GRID_LOCK = 10;
	const uint M_MALL = 11;
	const uint M_ON_THE_ROAD = 16;
	const uint M_BIG_RACE = 22;
	const uint M_VICTORY = 25;
	const uint M_GAME_OVER = 27;

	List<uint> M_CITY_MISSIONS = new List<uint> {M_QUICKSHOT, M_CAR_WASH, M_CAR_PARK, M_CREATURE, M_ALIEN, M_SPEED_HUMPS, M_TAXI_RANK, M_GRID_LOCK, M_MALL};

	const uint PLAYER_CITY_PRE_MISSION = 0;
	const uint PLAYER_CITY_MISSION = 1;
	const uint PLAYER_CITY_POST_MISSION = 2;
	const uint PLAYER_ROAD = 3;
	const uint PLAYER_BIG_RACE = 4;

	Func<uint?, uint?, bool> IsMusicTransitionFromTo = (qFrom, qTo) => {
		if (old.music_track == current.music_track)
		{
			return false;
		}
		if (qFrom.HasValue && old.music_track != qFrom) {
			return false;
		}
		if (qTo.HasValue && current.music_track != qTo) {
			return false;
		}
		return true;
	};

	if (settings["BigRace"])
	{		
		// road -> city: split maybe
		// Need to rely on player state because music before In The City could be Road, Duel or Video Mode (or SWay Frenzy after Big Race Win). We also assume of course that road play is enabled in the first place.
		if (vars.playerState == PLAYER_ROAD && IsMusicTransitionFromTo(null, M_AT_A_CITY))
		{
			vars.DebugOutput("Player entered city.");
			vars.playerState = PLAYER_CITY_PRE_MISSION;
			if (settings["SplitEnterCities"])
			{
				return true;
			}
		}
		// city -> mission: split maybe
		else if (vars.playerState == PLAYER_CITY_PRE_MISSION && M_CITY_MISSIONS.Any(m => IsMusicTransitionFromTo(M_AT_A_CITY, m)))
		{
			vars.DebugOutput("Player started city mission.");
			vars.playerState = PLAYER_CITY_MISSION;
			if (settings["SplitCityMissions"])
			{
				return true;
			}
		}
		// city -> Big Race: split maybe
		else if (vars.playerState == PLAYER_CITY_PRE_MISSION && IsMusicTransitionFromTo(M_AT_A_CITY, M_BIG_RACE))
		{
			vars.DebugOutput("Player started Big Race.");		
			vars.playerState = PLAYER_BIG_RACE;
			if (settings["SplitBigRaceStart"] || settings["SplitCityMissions"])
			{
				return true;
			}
		}
		// Big Race -> victory (or In the City): split maybe
		else if (vars.playerState == PLAYER_BIG_RACE && IsMusicTransitionFromTo(M_BIG_RACE, null))
		{
			vars.DebugOutput("Player is 'On the Road' after Big Race win.");
			vars.playerState = PLAYER_ROAD;		// lost in the outskirts of NY...
			if (settings["SplitBigRaceEnd"] || settings["SplitCityMissions"])
			{
				return true;
			}
		}
		// mission -> city: split maybe
		// Need to rely on player state. Passenger Frenzies can start during Speed Humps for example, which changes the music.
		else if (vars.playerState == PLAYER_CITY_MISSION && IsMusicTransitionFromTo(null, M_AT_A_CITY))
		{
			vars.DebugOutput("Player has passed city mission.");
			vars.playerState = PLAYER_CITY_POST_MISSION;
			if (settings["SplitCityMissions"])
			{
				return true;
			}
		}
		// city -> road: split maybe
		// Need to rely on player state because music before On The Road could be In The City or Jay's.
		else if (vars.playerState == PLAYER_CITY_POST_MISSION && IsMusicTransitionFromTo(null, M_ON_THE_ROAD))
		{
			vars.DebugOutput("Player has hit the road.");
			vars.playerState = PLAYER_ROAD;
			if (settings["SplitExitCities"])
			{
				return true;
			}
		}		
	}

	if (settings["Score"])
	{
        var milestones = new List<long> {250000000, 500000000, 750000000, 1000000000, 1250000000, 1500000000};
        foreach(var milestone in milestones)
        {
        	if (old.p1_score < milestone && current.p1_score >= milestone)
			{
				vars.DebugOutput(string.Format("P1 has reached {0} points, splitting.", milestone));
				return true;
			}
        }		
	}

	// game over -> pause timer
	if (IsMusicTransitionFromTo(null, M_GAME_OVER))
	{
		timer.IsGameTimePaused = true;
	}

	return false;
}

isLoading
{
	const uint M_BONUS_COUNT = 26;
	return current.music_track == M_BONUS_COUNT;
}
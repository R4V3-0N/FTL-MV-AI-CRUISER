local string_starts = mods.multiverse.string_starts
local userdata_table = mods.multiverse.userdata_table

-- Pick a random name for the rebel cruisers
do
    local rebelCruiserNames = {
        "Oooo, Doughnuts",
        "Wrecking Ball",
        "Cuddle Buddy",
        "Suck It Up",
        "That's Gotta Sting",
        "Slippery When Wet",
        "Discount Muffler",
        "Space Radish",
        "Look, A Squirrel!",
        "Up Your Kilt",
        "Date Your Sister?",
        "Nocturnal Emission",
        "Cut To The Chase",
        "Space Booger",
        "Big Sexy Beast",
        "Chatterbox",
        "In The Out Door",
        "Merry Go Round",
        "End Of Invention",
        "Socialization Fail",
        "Pain Of Rejection",
        "Pew!Pew!Pew!",
        "End Of Inventions",
        "Ablation",
        "Pure Mad Boat Man",
        "Undesirable Alien",
        "Zero Credibility",
        "Mutual Respect",
        "Gravitas Shortfall",
        "Hey Diddly Diddly",
        "Spilt Milk",
        "Meaty Goodness",
        "Problem Child",
        "Recent Convert",
        "Cleanup Crew",
        "Dirty Whistle",
        "Petty Mischief",
        "Six Pack Abs",
        "Terminal Damage",
        "Size Is Everything",
        "Dirty Dancing",
        "Disco Love",
        "Double Bubble",
        "Muskrat Love",
        "I Am The Walrus",
        "Beautiful Noise",
        "Bacon Is Truth",
        "Talking Trash",
        "Gobble Gobble",
        "Cat's Cradle",
        "Cute Little Thing",
        "Fog Of Peace",
        "Roll The Dice",
        "Next Big Thing",
        "Kiss My Grits",
        "Momma Done Told Me",
        "No Worries",
        "Brute Force",
        "Nasty Rash",
        "New In Town",
        "Cake Eater",
        "Whoopie Cushion",
        "Invincible",
        "Broken Dreams",
        "Not Sold In Stores",
        "Crowd Dispersal",
        "Circuit Breaker",
        "Grinding Fun",
        "Rapid Response",
        "Father Of Guns",
        "To-Do List",
        "Excessive Force",
        "They Hate Me",
        "By The Power Of Ra",
        "Speling Erors",
        "Correction Utility",
        "Educator",
        "Application Form",
        "Pillow Fight",
        "BBQ Chips",
        "Dirty Unicorn",
        "Bad Day",
        "Bad Habits",
        "No Joy",
        "Gun Addict",
        "Pig In A Poke",
        "Shield Freak",
        "Pro Gamer",
        "I'm Telling Mama",
        "Meat Eater",
        "Big Bam Boom",
        "Socially Awkward",
        "Price Of Water",
        "Arsonist",
        "Try Me",
        "Advanced Chemistry",
        "Baloney",
        "Ground Zero",
        "Sun Gazer",
        "Electro Junky",
        "Baseline",
        "Hedonists Pride",
        "Village Idiot",
        "Pretzel Sticks",
        "Economy Size",
        "Plaything",
        "Space Census",
        "Burst Damage",
        "Immovable Object",
        "Cataclysmic Event",
        "Hostile Encounter",
        "Braindead",
        "Head Trauma",
        "Troubled Childhood",
        "Mindless Tool",
        "Attitude Adjuster",
        "Corrector",
        "I Want My Mommy",
        "Pithy Sayings",
        "Lapsed Pacifist",
        "Lasting Damage",
        "New Recruit",
        "Isn't it Ironic?",
        "Pretty Good Shot",
        "Beacon Eater",
        "Sun Hugger",
        "Pain Maximizer",
        "Sugarcoated",
        "Gangsters Paradise",
        "Promises Broken",
        "Disappointing Son",
        "Laser Therapy",
        "Bernie's Wrath",
        "System Nerd",
        "Brass Bandit",
        "Boogie Man",
        "Get Off My Lawn",
        "Constipated",
        "Tourist Season",
        "Drone Lover",
        "Danger Zone",
        "Iron Beagle",
        "Advanced Bookstore",
        "Alabaster Barrel",
        "Impact Calculation",
        "Roadkill Producer",
        "Whack Bunny",
        "Occipital Region",
        "Well Sorted",
        "Well Behaved",
        "Just Go Away",
        "Superstitious",
        "You Can't Drive",
        "A Million Missiles",
        "Orbital Striker",
        "Beam-Burned",
        "Deluxe Version",
        "Teleport Everyone",
        "Lunatic Fringe",
        "Scatterbrained",
        "Jah No Partial",
        "Goa Goa MPU Ja",
        "I Shot a Man Down",
        "Base Drop",
        "Herbivore",
        "BS Loadout",
        "Hyper Cheese",
        "Hyperspace Admiral",
        "FTL Throne"
    }
    local justStartedGame = false
    script.on_init(function(newGame) justStartedGame = not newGame end)
    script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
        if justStartedGame then
            justStartedGame = not Hyperspace.App.world.bStartedGame
            return
        end
        if not Hyperspace.App.world.bStartedGame and string_starts(ship.myBlueprint.blueprintName, "PLAYER_SHIP_RVSP_REBEL_ALT") then
            local shipTable = userdata_table(ship, "mods.ai.shipStuff")
            if not shipTable.renamedRebelCruiser then
                ship.myBlueprint.name.data = rebelCruiserNames[math.random(#rebelCruiserNames)]
                shipTable.renamedRebelCruiser = true
            end
        end
    end)
end

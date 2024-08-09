return {
    minSpawnDist = 150.0, -- Min distance that a taxi will spawn from the player (in-game units)
    noPayAlert = true, -- Toggle PD alert if fare not paid
    drivingStyles = { -- See https://vespura.com/fivem/drivingstyle/
        normal = {
            style = 524731,
            speedMult = 1.0,
            aggressiveness = 0.5,
        },
        rush = {
            style = 787263,
            speedMult = 1.5,
            aggressiveness = 0.75,
        },
    },
    tiers = {
        cab = {
            label = 'Taxi',
            models = { 'taxi', },
            fare = {
                base = 1.0,
                tick = 0.25,
                tickTime = 30,
            },
            driver = {
                model = 'a_m_y_stlat_01',
                voice = 'A_M_M_EASTSA_02_LATINO_FULL_01',
            },
            extras = {
                [1] = false,
                [2] = false,
                [3] = false,
                [4] = false,
                [5] = false,
                [6] = true,
                [7] = false,
                [8] = false,
                [9] = false,
                [10] = false,
                [11] = false,
                [12] = false,
                [13] = false,
                [14] = false,
            },
        },
        limo = {
            label = 'Limo',
            models = { 'stretch', },
            fare = {
                base = 1.0,
                tick = 0.25,
                tickTime = 30,
            },
            driver = {
                model = 'a_m_y_smartcaspat_01',
                voice = 'A_M_M_EASTSA_02_LATINO_FULL_01',
            },
            extras = {
                [1] = false,
                [2] = false,
                [3] = false,
                [4] = false,
                [5] = false,
                [6] = true,
                [7] = false,
                [8] = false,
                [9] = false,
                [10] = false,
                [11] = false,
                [12] = false,
                [13] = false,
                [14] = false,
            },
        },
    },
    speedLimitZones = { -- Speeds in MPH
        [2] = 40, -- City / main roads
        [10] = 30, -- Slow roads
        [64] = 25, -- Off road
        [66] = 60, -- Freeway
        [82] = 60, -- Freeway tunnels
    },
}

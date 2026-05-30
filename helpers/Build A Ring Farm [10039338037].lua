local Seeds = {
    --Common [1-3] +3 3-8
    ["Carrot"] = { index = 1, price = 3, chance = "33.333333%", source = "Rolling", rarity = "Common" },
    ["Beetroot"] = { index = 2, price = 5, chance = "33.333333%", source = "Rolling", rarity = "Common" },
    ["Pumpkin"] = { index = 3, price = 8, chance = "25%", source = "Rolling", rarity = "Common" },
    --Uncommon [4-8] +5 12-30
    ["Wheat"] = { index = 4, price = 12, chance = "3.125%", source = "Rolling", rarity = "Uncommon" },
    ["Melon"] = { index = 5, price = 18, chance = "3.125%", source = "Rolling", rarity = "Uncommon" },
    ["Onion"] = { index = 6, price = 20, chance = "1.960784%", source = "Rolling", rarity = "Uncommon" },
    ["Cantaloupe"] = { index = 7, price = 25, chance = "1.5625%", source = "Rolling", rarity = "Uncommon" },
    ["Watermelon"] = { index = 8, price = 30, chance = "1.176471%", source = "Rolling", rarity = "Uncommon" },
    --Rare [9-13] +5 50-180
    ["Blueberry"] = { index = 9, price = 50, chance = "0.78125%", source = "Rolling", rarity = "Rare" },
    ["Cabbage"] = { index = 10, price = 85, chance = "0.390625%", source = "Rolling", rarity = "Rare" },
    ["Grape"] = { index = 11, price = 120, chance = "0.234192%", source = "Rolling", rarity = "Rare" },
    ["Bamboo"] = { index = 12, price = 160, chance = "0.15625%", source = "Rolling", rarity = "Rare" },
    ["Peach"] = { index = 13, price = 180, chance = "0.195313%", source = "Rolling", rarity = "Rare" },
    --Epic [14-19] +6 250-700
    ["Corn"] = { index = 14, price = 250, chance = "0.175747%", source = "Rolling", rarity = "Epic" },
    ["Plum"] = { index = 15, price = 300, chance = "0.117096%", source = "Rolling", rarity = "Epic" },
    ["Cauliflower"] = { index = 16, price = 400, chance = "0.078064%", source = "Rolling", rarity = "Epic" },
    ["Nectarine"] = { index = 17, price = 480, chance = "0.070274%", source = "Rolling", rarity = "Epic" },
    ["Sunflower"] = { index = 18, price = 550, chance = "0.070274%", source = "Rolling", rarity = "Epic" },
    ["Citrus"] = { index = 19, price = 700, chance = "0.039047%", source = "Rolling", rarity = "Epic" },
    --Legendary [20-23] +4 1.2K-2.5K
    ["Spring Onion"] = { index = 20, price = 1200, chance = "0.03123%", source = "Rolling", rarity = "Legendary" },
    ["Mango"] = { index = 21, price = 1600, chance = "N/A", source = "Seed Collector", rarity = "Legendary" },
    ["Mushroom"] = { index = 22, price = 2000, chance = "0.015615%", source = "Rolling", rarity = "Legendary" },
    ["Banana"] = { index = 23, price = 2500, chance = "0.011712%", source = "Rolling", rarity = "Legendary" },
    --Secret [24-28] +5 6K-13K
    ["Strawberry"] = { index = 24, price = 6000, chance = "0.007808%", source = "Rolling", rarity = "Secret" },
    ["Glowshroom"] = { index = 25, price = 8000, chance = "5%", source = "Seed Packs", rarity = "Secret" },
    ["Beanstalk"] = { index = 26, price = 9000, chance = "0.003904%", source = "Rolling", rarity = "Secret" },
    ["Tomato"] = { index = 27, price = 12000, chance = "0.001952%", source = "Rolling", rarity = "Secret" },
    ["Starfruit"] = { index = 28, price = 13000, chance = "5%", source = "Seed Packs", rarity = "Secret" },
    --Prismatic [29-31] +3 20K-40K
    ["Apple"] = { index = 29, price = 20000, chance = "0.000781%", source = "Rolling", rarity = "Prismatic" },
    ["Cherry Blossom"] = { index = 30, price = 30000, chance = "0.00039%", source = "Rolling", rarity = "Prismatic" },
    ["Pineapple"] = { index = 31, price = 40000, chance = "25%", source = "Seed Packs", rarity = "Prismatic" },
    --Divine [32-34] +3 55K-65K
    ["Diamond Blossom"] = { index = 32, price = 55000, chance = "100%", source = "Special Daily Quests, Seed Collector", rarity = "Divine" },
    ["Pomegranate"] = { index = 33, price = 75000, chance = "15%", source = "Seed Packs", rarity = "Divine" },
    ["Golden Apple"] = { index = 34, price = 65000, chance = "0.000234%", source = "Rolling", rarity = "Divine" },
    --Exotic [35-39] +5 90K-350K
    ["Kiwi"] = { index = 35, price = 90000, chance = "9%", source = "Seed Packs", rarity = "Exotic" },
    ["Moonflower"] = { index = 36, price = 110000, chance = "0.000137%", source = "Rolling", rarity = "Exotic" },
    ["Pepper"] = { index = 37, price = 140000, chance = "0.00007%", source = "Rolling", rarity = "Exotic" },
    ["Void Fruit"] = { index = 38, price = 180000, chance = "0.000004%", source = "Rolling", rarity = "Exotic" },
    ["Dragonfruit"] = { index = 39, price = 350000, chance = "1%", source = "Seed Packs", rarity = "Exotic" },
}

return Seeds

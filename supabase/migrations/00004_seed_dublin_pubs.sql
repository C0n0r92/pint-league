-- Seed Dublin Pubs - Comprehensive list of popular pubs across Dublin

INSERT INTO public.pubs (name, lat, lng, address, city, country, categories) VALUES
-- Temple Bar Area
('The Temple Bar', 53.3455, -6.2644, '47-48 Temple Bar', 'Dublin', 'IE', ARRAY['pub']),
('The Quays Bar', 53.3456, -6.2638, '11-12 Temple Bar', 'Dublin', 'IE', ARRAY['pub']),
('Oliver St. John Gogarty', 53.3452, -6.2633, '58-59 Fleet St', 'Dublin', 'IE', ARRAY['pub']),
('The Auld Dubliner', 53.3451, -6.2628, '24-25 Temple Bar', 'Dublin', 'IE', ARRAY['pub']),
('The Porterhouse Temple Bar', 53.3448, -6.2641, '16-18 Parliament St', 'Dublin', 'IE', ARRAY['pub']),
('Bad Bobs Temple Bar', 53.3453, -6.2620, '35-36 East Essex St', 'Dublin', 'IE', ARRAY['pub']),
('The Norseman', 53.3460, -6.2650, '28 East Essex St', 'Dublin', 'IE', ARRAY['pub']),
('The Turks Head', 53.3449, -6.2654, '27 Parliament St', 'Dublin', 'IE', ARRAY['pub']),

-- Grafton Street Area
('Kehoe''s', 53.3413, -6.2590, '9 South Anne St', 'Dublin', 'IE', ARRAY['pub']),
('Bruxelles', 53.3422, -6.2604, '7-8 Harry St', 'Dublin', 'IE', ARRAY['pub']),
('The International Bar', 53.3437, -6.2598, '23 Wicklow St', 'Dublin', 'IE', ARRAY['pub']),
('McDaids', 53.3420, -6.2596, '3 Harry St', 'Dublin', 'IE', ARRAY['pub']),
('Grogan''s Castle Lounge', 53.3419, -6.2637, '15 South William St', 'Dublin', 'IE', ARRAY['pub']),
('The Dawson Lounge', 53.3406, -6.2580, '25 Dawson St', 'Dublin', 'IE', ARRAY['pub']),
('Cafe en Seine', 53.3403, -6.2575, '40 Dawson St', 'Dublin', 'IE', ARRAY['pub']),
('Sam''s Bar', 53.3410, -6.2573, '35 Dawson St', 'Dublin', 'IE', ARRAY['pub']),

-- George''s Street Area
('The Long Hall', 53.3428, -6.2653, '51 South Great George''s St', 'Dublin', 'IE', ARRAY['pub']),
('The Stag''s Head', 53.3433, -6.2627, '1 Dame Ct', 'Dublin', 'IE', ARRAY['pub']),
('The Dame Tavern', 53.3432, -6.2621, '2 Dame Ct', 'Dublin', 'IE', ARRAY['pub']),
('Hogans', 53.3418, -6.2644, '35 South Great George''s St', 'Dublin', 'IE', ARRAY['pub']),
('The George', 53.3423, -6.2649, '89 South Great George''s St', 'Dublin', 'IE', ARRAY['pub']),
('Whelan''s', 53.3390, -6.2633, '25 Wexford St', 'Dublin', 'IE', ARRAY['pub']),

-- Baggot Street / Merrion Area
('Toner''s', 53.3378, -6.2521, '139 Lower Baggot St', 'Dublin', 'IE', ARRAY['pub']),
('O''Donoghue''s', 53.3372, -6.2503, '15 Merrion Row', 'Dublin', 'IE', ARRAY['pub']),
('Doheny & Nesbitt', 53.3375, -6.2510, '5 Lower Baggot St', 'Dublin', 'IE', ARRAY['pub']),
('The Baggot Inn', 53.3356, -6.2469, '143 Lower Baggot St', 'Dublin', 'IE', ARRAY['pub']),
('Searsons', 53.3349, -6.2449, '42 Upper Baggot St', 'Dublin', 'IE', ARRAY['pub']),
('The Pembroke', 53.3340, -6.2432, '31 Upper Pembroke St', 'Dublin', 'IE', ARRAY['pub']),

-- City Centre
('The Palace Bar', 53.3457, -6.2604, '21 Fleet St', 'Dublin', 'IE', ARRAY['pub']),
('Mulligan''s', 53.3469, -6.2541, '8 Poolbeg St', 'Dublin', 'IE', ARRAY['pub']),
('The Oval', 53.3493, -6.2562, '78 Middle Abbey St', 'Dublin', 'IE', ARRAY['pub']),
('The Confession Box', 53.3500, -6.2590, 'Marlborough St', 'Dublin', 'IE', ARRAY['pub']),
('Madigan''s', 53.3499, -6.2540, 'Earl St North', 'Dublin', 'IE', ARRAY['pub']),
('The Flowing Tide', 53.3492, -6.2568, '9 Lower Abbey St', 'Dublin', 'IE', ARRAY['pub']),

-- Smithfield / Stoneybatter
('The Brazen Head', 53.3449, -6.2773, '20 Lower Bridge St', 'Dublin', 'IE', ARRAY['pub']),
('The Cobblestone', 53.3489, -6.2782, '77 King St North', 'Dublin', 'IE', ARRAY['pub']),
('L. Mulligan Grocer', 53.3512, -6.2801, '18 Stoneybatter', 'Dublin', 'IE', ARRAY['pub']),
('The Dice Bar', 53.3478, -6.2778, '79 Queen St', 'Dublin', 'IE', ARRAY['pub']),
('Frank Ryan''s', 53.3507, -6.2793, '2 Queen St', 'Dublin', 'IE', ARRAY['pub']),
('Walsh''s Stoneybatter', 53.3519, -6.2815, '6 Stoneybatter', 'Dublin', 'IE', ARRAY['pub']),

-- Portobello / Rathmines
('The Barge', 53.3325, -6.2640, '42 Charlemont St', 'Dublin', 'IE', ARRAY['pub']),
('Fallon''s', 53.3360, -6.2735, '129 The Coombe', 'Dublin', 'IE', ARRAY['pub']),
('The Lower Deck', 53.3297, -6.2637, '1 Portobello Harbour', 'Dublin', 'IE', ARRAY['pub']),
('The Bernard Shaw', 53.3324, -6.2680, '11 South Richmond St', 'Dublin', 'IE', ARRAY['pub']),
('Mother Reilly''s', 53.3247, -6.2625, '189 Rathmines Rd Lower', 'Dublin', 'IE', ARRAY['pub']),

-- Ranelagh
('Smyth''s of Ranelagh', 53.3259, -6.2553, '19 Ranelagh', 'Dublin', 'IE', ARRAY['pub']),
('The Hill', 53.3255, -6.2547, '61 Ranelagh', 'Dublin', 'IE', ARRAY['pub']),
('McSorley''s', 53.3262, -6.2541, '37 Ranelagh', 'Dublin', 'IE', ARRAY['pub']),
('Birchall''s', 53.3248, -6.2565, '32 Ranelagh', 'Dublin', 'IE', ARRAY['pub']),

-- Drumcondra / Phibsboro
('The Cat & Cage', 53.3640, -6.2588, '10 Drumcondra Rd Upper', 'Dublin', 'IE', ARRAY['pub']),
('Fagan''s', 53.3641, -6.2595, '1 Drumcondra Rd Lower', 'Dublin', 'IE', ARRAY['pub']),
('The Gravediggers (John Kavanagh''s)', 53.3719, -6.2754, '1 Prospect Square', 'Dublin', 'IE', ARRAY['pub']),
('The Hut', 53.3578, -6.2701, '159 Phibsborough Rd', 'Dublin', 'IE', ARRAY['pub']),
('Doyle''s Corner', 53.3591, -6.2707, '169 Phibsborough Rd', 'Dublin', 'IE', ARRAY['pub']),

-- Clontarf / Fairview
('The Yacht', 53.3600, -6.2095, '2 Clontarf Rd', 'Dublin', 'IE', ARRAY['pub']),
('The Sheds', 53.3587, -6.2120, '26 Clontarf Rd', 'Dublin', 'IE', ARRAY['pub']),
('Gaffney''s', 53.3595, -6.2410, '12 Fairview Strand', 'Dublin', 'IE', ARRAY['pub']),
('The Fairview Inn', 53.3592, -6.2395, '1 Fairview Strand', 'Dublin', 'IE', ARRAY['pub']),

-- Glasnevin
('The Gravediggers (John Kavanagh''s)', 53.3719, -6.2754, '1 Prospect Square', 'Dublin', 'IE', ARRAY['pub']),
('The Brian Boru', 53.3713, -6.2758, '5 Prospect Rd', 'Dublin', 'IE', ARRAY['pub']),
('Hedigan''s', 53.3708, -6.2780, '11 Botanic Rd', 'Dublin', 'IE', ARRAY['pub']),

-- Howth
('The Bloody Stream', 53.3865, -6.0677, '2 Howth Rd', 'Howth', 'IE', ARRAY['pub']),
('Abbey Tavern', 53.3892, -6.0705, '28 Abbey St', 'Howth', 'IE', ARRAY['pub']),
('The Cock Tavern', 53.3873, -6.0682, 'Church St', 'Howth', 'IE', ARRAY['pub']),
('Findlater''s', 53.3880, -6.0665, '1 The Harbour', 'Howth', 'IE', ARRAY['pub']),

-- Dalkey / Dun Laoghaire
('Finnegan''s', 53.2780, -6.1005, '1 Sorrento Rd', 'Dalkey', 'IE', ARRAY['pub']),
('The Queen''s', 53.2782, -6.0995, '12 Castle St', 'Dalkey', 'IE', ARRAY['pub']),
('The Club', 53.2778, -6.0988, '8 Railway Rd', 'Dalkey', 'IE', ARRAY['pub']),
('Fitzgerald''s', 53.2920, -6.1340, '28 Marine Rd', 'Dun Laoghaire', 'IE', ARRAY['pub']),
('The Purty Kitchen', 53.2925, -6.1355, '3 Old Dunleary Rd', 'Dun Laoghaire', 'IE', ARRAY['pub']),

-- Blackrock / Booterstown
('Whelans of Blackrock', 53.3015, -6.1783, '1 Main St', 'Blackrock', 'IE', ARRAY['pub']),
('The Punch Bowl', 53.3024, -6.1801, '18 Main St', 'Blackrock', 'IE', ARRAY['pub']),
('McGowan''s', 53.3098, -6.1955, '7 Booterstown Ave', 'Booterstown', 'IE', ARRAY['pub']),

-- Sandymount / Ringsend
('The Bath', 53.3302, -6.2155, '5 Bath Ave', 'Sandymount', 'IE', ARRAY['pub']),
('Sandymount House', 53.3290, -6.2180, '1 Sandymount Green', 'Sandymount', 'IE', ARRAY['pub']),
('The Oarsman', 53.3395, -6.2290, '19 Bridge St', 'Ringsend', 'IE', ARRAY['pub']),
('Ringsend House', 53.3400, -6.2275, '1 Fitzwilliam St', 'Ringsend', 'IE', ARRAY['pub'])

ON CONFLICT DO NOTHING;


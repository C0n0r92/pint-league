-- Seed Lucan and Newcastle Pubs

INSERT INTO public.pubs (name, lat, lng, address, city, country, categories) VALUES
-- Lucan Village
('The Spa Hotel', 53.3537, -6.4488, 'Lucan Rd', 'Lucan', 'IE', ARRAY['pub', 'hotel']),
('The Foxhunter', 53.3542, -6.4512, 'Main St', 'Lucan', 'IE', ARRAY['pub']),
('Finnstown House Hotel', 53.3445, -6.4298, 'Newcastle Rd', 'Lucan', 'IE', ARRAY['pub', 'hotel']),
('The Village Inn', 53.3539, -6.4495, 'Main St', 'Lucan', 'IE', ARRAY['pub']),
('Kenny''s of Lucan', 53.3544, -6.4508, 'Main St', 'Lucan', 'IE', ARRAY['pub']),
('The Hideout', 53.3535, -6.4480, 'Chapel Hill', 'Lucan', 'IE', ARRAY['pub']),
('Doyle''s Lucan', 53.3540, -6.4502, 'Main St', 'Lucan', 'IE', ARRAY['pub']),
('The Lucan Spa Hotel Bar', 53.3538, -6.4490, 'Lucan Rd', 'Lucan', 'IE', ARRAY['pub']),

-- Lucan - Griffeen Area
('The Wetherspoons Lucan', 53.3485, -6.4395, 'Liffey Valley', 'Lucan', 'IE', ARRAY['pub']),
('The Mill', 53.3510, -6.4420, 'Griffeen Glen', 'Lucan', 'IE', ARRAY['pub']),

-- Newcastle (South Dublin)
('The Newcastle Inn', 53.3012, -6.4932, 'Main St', 'Newcastle', 'IE', ARRAY['pub']),
('Lynham''s of Newcastle', 53.3015, -6.4928, 'Main St', 'Newcastle', 'IE', ARRAY['pub']),
('The Athgoe Bar', 53.2998, -6.4945, 'Athgoe Rd', 'Newcastle', 'IE', ARRAY['pub']),
('McEvoy''s Newcastle', 53.3010, -6.4935, 'Main St', 'Newcastle', 'IE', ARRAY['pub']),
('The Lamplighter', 53.3008, -6.4940, 'Newcastle Village', 'Newcastle', 'IE', ARRAY['pub']),

-- Nearby - Clondalkin
('The Steering Wheel', 53.3205, -6.3948, 'Monastery Rd', 'Clondalkin', 'IE', ARRAY['pub']),
('The Laurels', 53.3198, -6.3920, 'Main St', 'Clondalkin', 'IE', ARRAY['pub']),
('The Foxhound', 53.3210, -6.3935, 'Tower Rd', 'Clondalkin', 'IE', ARRAY['pub']),
('The Poitin Stil', 53.3195, -6.3965, 'New Rd', 'Clondalkin', 'IE', ARRAY['pub']),
('The Village Inn Clondalkin', 53.3200, -6.3942, 'Village Square', 'Clondalkin', 'IE', ARRAY['pub']),

-- Nearby - Celbridge
('The Celbridge Manor Hotel', 53.3412, -6.5385, 'Clane Rd', 'Celbridge', 'IE', ARRAY['pub', 'hotel']),
('The Village Inn Celbridge', 53.3380, -6.5398, 'Main St', 'Celbridge', 'IE', ARRAY['pub']),
('Brady''s Celbridge', 53.3375, -6.5402, 'Main St', 'Celbridge', 'IE', ARRAY['pub']),
('The Slip Inn', 53.3368, -6.5410, 'Main St', 'Celbridge', 'IE', ARRAY['pub']),

-- Nearby - Rathcoole
('The Poitín Stil Rathcoole', 53.2858, -6.4612, 'Main St', 'Rathcoole', 'IE', ARRAY['pub']),
('An Poitín Stil', 53.2860, -6.4608, 'Main St', 'Rathcoole', 'IE', ARRAY['pub']),
('The Kilteel Inn', 53.2545, -6.5125, 'Kilteel Rd', 'Kilteel', 'IE', ARRAY['pub']),

-- Nearby - Saggart
('The Foxhunter Saggart', 53.2785, -6.4425, 'Main St', 'Saggart', 'IE', ARRAY['pub']),
('Citywest Hotel Bar', 53.2755, -6.4380, 'Citywest', 'Saggart', 'IE', ARRAY['pub', 'hotel'])

ON CONFLICT DO NOTHING;


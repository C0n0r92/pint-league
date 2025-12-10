// Seed pubs from OpenStreetMap Overpass API
// Run this edge function to populate the pubs table

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const OVERPASS_URL = 'https://overpass-api.de/api/interpreter'

// Chunk by UK regions + Ireland for reliable API calls
const REGIONS = [
  { name: 'Ireland', query: 'area["ISO3166-1"="IE"]', country: 'IE' },
  { name: 'Northern Ireland', query: 'area["name"="Northern Ireland"]["admin_level"="4"]', country: 'GB' },
  { name: 'Scotland', query: 'area["name"="Scotland"]["admin_level"="4"]', country: 'GB' },
  { name: 'Wales', query: 'area["name"="Wales"]["admin_level"="4"]', country: 'GB' },
  { name: 'London', query: 'area["name"="Greater London"]["admin_level"="5"]', country: 'GB' },
  { name: 'South East', query: 'area["name"="South East England"]["admin_level"="5"]', country: 'GB' },
  { name: 'South West', query: 'area["name"="South West England"]["admin_level"="5"]', country: 'GB' },
  { name: 'East of England', query: 'area["name"="East of England"]["admin_level"="5"]', country: 'GB' },
  { name: 'West Midlands', query: 'area["name"="West Midlands"]["admin_level"="5"]', country: 'GB' },
  { name: 'East Midlands', query: 'area["name"="East Midlands"]["admin_level"="5"]', country: 'GB' },
  { name: 'Yorkshire', query: 'area["name"="Yorkshire and the Humber"]["admin_level"="5"]', country: 'GB' },
  { name: 'North West', query: 'area["name"="North West England"]["admin_level"="5"]', country: 'GB' },
  { name: 'North East', query: 'area["name"="North East England"]["admin_level"="5"]', country: 'GB' },
]

interface OsmElement {
  id: number
  lat?: number
  lon?: number
  center?: { lat: number; lon: number }
  tags?: {
    name?: string
    amenity?: string
    'addr:street'?: string
    'addr:housenumber'?: string
    'addr:city'?: string
    'addr:postcode'?: string
  }
}

async function seedRegion(region: typeof REGIONS[0]): Promise<any[]> {
  const query = `
    [out:json][timeout:180];
    ${region.query}->.searchArea;
    (
      node["amenity"~"pub|bar|biergarten"](area.searchArea);
      way["amenity"~"pub|bar|biergarten"](area.searchArea);
    );
    out center;
  `

  try {
    const response = await fetch(OVERPASS_URL, {
      method: 'POST',
      body: `data=${encodeURIComponent(query)}`,
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    })

    if (!response.ok) {
      console.error(`Failed to fetch ${region.name}: ${response.status}`)
      return []
    }

    const data = await response.json()
    
    return data.elements.map((el: OsmElement) => ({
      osm_id: el.id,
      name: el.tags?.name || 'Unknown Pub',
      lat: el.lat || el.center?.lat,
      lng: el.lon || el.center?.lon,
      address: el.tags?.['addr:street']
        ? `${el.tags['addr:housenumber'] || ''} ${el.tags['addr:street']}`.trim()
        : null,
      city: el.tags?.['addr:city'] || null,
      country: region.country,
      categories: [el.tags?.amenity].filter(Boolean),
    })).filter((p: any) => p.lat && p.lng)
    
  } catch (error) {
    console.error(`Error fetching ${region.name}:`, error)
    return []
  }
}

Deno.serve(async (req) => {
  // Only allow POST requests (to prevent accidental triggers)
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { 
      status: 405,
      headers: { 'Content-Type': 'application/json' }
    })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const results: { region: string; count: number; error?: string }[] = []
  let totalPubs = 0

  for (const region of REGIONS) {
    console.log(`Seeding ${region.name}...`)
    
    try {
      const pubs = await seedRegion(region)
      
      if (pubs.length > 0) {
        // Batch insert (upsert on osm_id) in chunks of 500
        for (let i = 0; i < pubs.length; i += 500) {
          const batch = pubs.slice(i, i + 500)
          
          const { error: dbError } = await supabase.from('pubs').upsert(batch, {
            onConflict: 'osm_id',
            ignoreDuplicates: false,
          })
          
          if (dbError) {
            console.error(`DB error for ${region.name}:`, dbError)
          }
        }
      }
      
      results.push({ region: region.name, count: pubs.length })
      totalPubs += pubs.length
      console.log(`Inserted ${pubs.length} pubs for ${region.name}`)
      
    } catch (error) {
      results.push({ region: region.name, count: 0, error: String(error) })
    }

    // Rate limit: wait 2 seconds between regions
    await new Promise(r => setTimeout(r, 2000))
  }

  return new Response(
    JSON.stringify({ 
      success: true, 
      total: totalPubs,
      regions: results 
    }),
    { headers: { 'Content-Type': 'application/json' } }
  )
})


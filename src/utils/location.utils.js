const { Client } = require('@mapbox/mapbox-sdk');
const mbxGeocoding = require('@mapbox/mapbox-sdk/services/geocoding');

const mapboxClient = new Client({ accessToken: process.env.MAPBOX_ACCESS_TOKEN });
const geocodingService = mbxGeocoding(mapboxClient);

// Predefined regions for more interesting gameplay
const regions = [
  { name: 'North America', bounds: { minLat: 25, maxLat: 60, minLng: -140, maxLng: -60 } },
  { name: 'Europe', bounds: { minLat: 35, maxLat: 70, minLng: -10, maxLng: 40 } },
  { name: 'Asia', bounds: { minLat: 10, maxLat: 55, minLng: 60, maxLng: 140 } },
  { name: 'South America', bounds: { minLat: -40, maxLat: 10, minLng: -80, maxLng: -35 } },
  { name: 'Africa', bounds: { minLat: -35, maxLat: 35, minLng: -20, maxLng: 50 } },
  { name: 'Oceania', bounds: { minLat: -45, maxLat: -10, minLng: 110, maxLng: 180 } }
];

const getRandomRegion = () => {
  return regions[Math.floor(Math.random() * regions.length)];
};

const getRandomCoordinatesInRegion = (region) => {
  const { bounds } = region;
  const lat = bounds.minLat + (Math.random() * (bounds.maxLat - bounds.minLat));
  const lng = bounds.minLng + (Math.random() * (bounds.maxLng - bounds.minLng));
  return [lng, lat];
};

const isValidLocation = async (coordinates) => {
  try {
    const response = await geocodingService.reverseGeocode({
      query: coordinates,
      types: ['country']
    }).send();

    return response.body.features.length > 0;
  } catch (error) {
    console.error('Error validating location:', error);
    return false;
  }
};

const getRandomLocation = async (maxAttempts = 5) => {
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const region = getRandomRegion();
    const coordinates = getRandomCoordinatesInRegion(region);
    
    if (await isValidLocation(coordinates)) {
      return {
        type: 'Point',
        coordinates,
        region: region.name
      };
    }
  }
  
  // Fallback to a guaranteed valid location if all attempts fail
  const fallbackLocations = [
    [-73.935242, 40.730610], // New York
    [2.352222, 48.856614],   // Paris
    [139.691706, 35.689487], // Tokyo
    [37.618423, 55.751244],  // Moscow
    [-0.127758, 51.507351]   // London
  ];
  
  return {
    type: 'Point',
    coordinates: fallbackLocations[Math.floor(Math.random() * fallbackLocations.length)],
    region: 'Fallback'
  };
};

module.exports = {
  getRandomLocation,
  isValidLocation
}; 
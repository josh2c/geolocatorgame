const Game = require('../models/game.model');
const User = require('../models/user.model');
const turf = require('@turf/turf');
const { getRandomLocation } = require('../utils/location.utils');

// Start a new game
const startGame = async (req, res) => {
  try {
    const location = await getRandomLocation();
    
    // Get static image URL for the location
    const staticImageUrl = `https://api.mapbox.com/styles/v1/mapbox/satellite-v9/static/${location.coordinates[0]},${location.coordinates[1]},14,0/600x400?access_token=${process.env.MAPBOX_ACCESS_TOKEN}`;
    
    res.json({
      location: location.coordinates,
      region: location.region,
      imageUrl: staticImageUrl,
      timestamp: Date.now()
    });
  } catch (error) {
    console.error('Error starting game:', error);
    res.status(500).json({ message: 'Error generating location' });
  }
};

// Submit a guess
const submitGuess = async (req, res) => {
  try {
    const { actualLocation, guessedLocation, timeSpent } = req.body;

    // Validate input
    if (!actualLocation || !guessedLocation || !Array.isArray(actualLocation) || !Array.isArray(guessedLocation)) {
      return res.status(400).json({ message: 'Invalid location format' });
    }

    // Calculate distance using Turf.js
    const from = turf.point(actualLocation);
    const to = turf.point(guessedLocation);
    const distance = turf.distance(from, to);

    // Create new game instance
    const game = new Game({
      user: req.user._id,
      actualLocation: {
        type: 'Point',
        coordinates: actualLocation
      },
      guessedLocation: {
        type: 'Point',
        coordinates: guessedLocation
      },
      distance,
      timeSpent,
      score: 0
    });

    // Calculate and set score
    game.score = game.calculateScore(distance);

    // Save game
    await game.save();

    // Update user's stats
    const user = await User.findById(req.user._id);
    user.gamesPlayed += 1;
    if (game.score > user.highScore) {
      user.highScore = game.score;
    }
    await user.save();

    // Generate result map image
    const resultMapUrl = `https://api.mapbox.com/styles/v1/mapbox/streets-v11/static/pin-s-a+ff0000(${actualLocation[0]},${actualLocation[1]}),pin-s-b+0000ff(${guessedLocation[0]},${guessedLocation[1]})/auto/600x400?access_token=${process.env.MAPBOX_ACCESS_TOKEN}`;

    res.json({
      distance,
      score: game.score,
      highScore: user.highScore,
      resultMapUrl,
      actualLocation,
      guessedLocation
    });
  } catch (error) {
    console.error('Error submitting guess:', error);
    res.status(400).json({ message: error.message });
  }
};

// Get high scores
const getHighScores = async (req, res) => {
  try {
    const highScores = await User.find({})
      .select('username highScore gamesPlayed')
      .sort({ highScore: -1 })
      .limit(10);

    res.json(highScores);
  } catch (error) {
    res.status(400).json({ message: error.message });
  }
};

// Get user's game history
const getGameHistory = async (req, res) => {
  try {
    const games = await Game.find({ user: req.user._id })
      .select('-__v')
      .sort({ createdAt: -1 })
      .limit(10);

    // Add result map URLs to each game
    const gamesWithMaps = games.map(game => {
      const resultMapUrl = `https://api.mapbox.com/styles/v1/mapbox/streets-v11/static/pin-s-a+ff0000(${game.actualLocation.coordinates[0]},${game.actualLocation.coordinates[1]}),pin-s-b+0000ff(${game.guessedLocation.coordinates[0]},${game.guessedLocation.coordinates[1]})/auto/600x400?access_token=${process.env.MAPBOX_ACCESS_TOKEN}`;
      return {
        ...game.toObject(),
        resultMapUrl
      };
    });

    res.json(gamesWithMaps);
  } catch (error) {
    res.status(400).json({ message: error.message });
  }
};

// Get global stats
const getGlobalStats = async (req, res) => {
  try {
    const stats = await Game.aggregate([
      {
        $group: {
          _id: null,
          totalGames: { $sum: 1 },
          averageScore: { $avg: '$score' },
          averageDistance: { $avg: '$distance' },
          bestScore: { $max: '$score' }
        }
      }
    ]);

    res.json(stats[0] || {
      totalGames: 0,
      averageScore: 0,
      averageDistance: 0,
      bestScore: 0
    });
  } catch (error) {
    res.status(400).json({ message: error.message });
  }
};

module.exports = {
  startGame,
  submitGuess,
  getHighScores,
  getGameHistory,
  getGlobalStats
}; 
const mongoose = require('mongoose');

const locationSchema = new mongoose.Schema({
  type: {
    type: String,
    enum: ['Point'],
    default: 'Point'
  },
  coordinates: {
    type: [Number],
    required: true
  }
});

const gameSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  actualLocation: {
    type: locationSchema,
    required: true
  },
  guessedLocation: {
    type: locationSchema,
    required: true
  },
  distance: {
    type: Number,
    required: true
  },
  score: {
    type: Number,
    required: true
  },
  timeSpent: {
    type: Number,  // Time spent in seconds
    required: true
  },
  completed: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true
});

// Index for location-based queries
gameSchema.index({ 'actualLocation': '2dsphere' });
gameSchema.index({ 'guessedLocation': '2dsphere' });

// Calculate score based on distance (in kilometers)
gameSchema.methods.calculateScore = function(distance) {
  // Maximum score is 5000 points
  // Score decreases exponentially with distance
  const maxScore = 5000;
  const maxDistance = 20000; // Maximum distance in km (half the Earth's circumference)
  
  if (distance >= maxDistance) return 0;
  
  // Score formula: max_score * e^(-distance/1000)
  const score = Math.round(maxScore * Math.exp(-distance / 1000));
  return Math.max(0, score);
};

const Game = mongoose.model('Game', gameSchema);

module.exports = Game; 
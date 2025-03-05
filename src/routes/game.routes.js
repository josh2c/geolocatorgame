const express = require('express');
const router = express.Router();
const { 
  startGame, 
  submitGuess, 
  getHighScores, 
  getGameHistory,
  getGlobalStats
} = require('../controllers/game.controller');
const auth = require('../middleware/auth.middleware');

// All game routes are protected
router.use(auth);

router.post('/start', startGame);
router.post('/guess', submitGuess);
router.get('/highscores', getHighScores);
router.get('/history', getGameHistory);
router.get('/stats', getGlobalStats);

module.exports = router; 
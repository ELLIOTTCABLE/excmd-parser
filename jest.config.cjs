module.exports = {
   projects: ['<rootDir>/packages/*'],
   coverageReporters: ['json', 'lcov', 'text', 'clover', 'html'],
   transform: {'\\.js$': ['babel-jest', {rootMode: 'upward'}]},
}

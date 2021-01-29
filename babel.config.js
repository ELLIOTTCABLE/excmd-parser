module.exports = {
   presets: ['@babel/env'],
   overrides: [
      {
         test: 'packages/excmd/**/*',
         presets: ['@babel/env', '@babel/preset-typescript'],
         plugins: [
            [
               '@babel/plugin-transform-runtime',
               {
                  useESModules: true,

                  // NOTE: It's unclear if this value supports semver ranges or not; but I am
                  //       choosing to duplicate the value from `package.json` precisely.
                  //
                  //       See: <https://github.com/babel/babel/blob/9808d2/packages/babel-plugin-transform-runtime/src/helpers.js#L4-L33>
                  version: '~7.8.3', // @babel/runtime version
               },
            ],
         ],
      },
   ],
   babelrcRoots: ['.', './packages/*'],
}

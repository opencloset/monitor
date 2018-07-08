const path = require('path');

module.exports = {
  mode: 'none',    // TODO: production 이랑 development 를 나누던데
  entry: './_typescripts/dashboard/room.tsx',
  module: {
    rules: [
      {
        test: /\.tsx?$/,
        use: 'ts-loader',
        exclude: /node_modules/
      },
      {
        test: /\.scss$/,
        use: [
          "style-loader", // creates style nodes from JS strings
          "css-loader", // translates CSS into CommonJS
          "sass-loader" // compiles Sass to CSS
        ]
      },
      {
        test: /\.css$/,
        use: [
          "style-loader",
          "css-loader"
        ]
      }
    ]
  },
  resolve: {
    // Add '.ts' and '.tsx' as resolvable extensions.
    extensions: [".ts", ".tsx", ".js", ".json"]
  },
  output: {
    path: path.resolve(__dirname, 'public', 'dist'),
    publicPath: '/dist/',
    filename: 'dashboard-room.js'
  }
};

const path = require('path');
const webpack = require('webpack');
const CleanWebpackPlugin = require('clean-webpack-plugin');

let pathsToClean = ['public/assets/dist'];

module.exports = {
  mode: 'production',
  devtool: 'inline-source-map',
  entry: {
    index: [
      './public/assets/coffee/common.coffee',
      './public/assets/coffee/index.coffee',
      './public/assets/coffee/default-css.coffee'
    ],
    preparation: [
      './public/assets/coffee/common.coffee',
      './public/assets/coffee/preparation.coffee',
      './public/assets/coffee/default-css.coffee'
    ],
    online: [
      './public/assets/coffee/common.coffee',
      './public/assets/coffee/online.coffee',
      './public/assets/coffee/dashboard-css.coffee'
    ],
    repair: [
      './public/assets/coffee/common.coffee',
      './public/assets/coffee/repair.coffee',
      './public/assets/coffee/default-css.coffee'
    ],
    room: [
      './public/assets/coffee/common.coffee',
      './public/assets/coffee/room.coffee',
      './public/assets/coffee/default-css.coffee'
    ],
    select: [
      './public/assets/coffee/common.coffee',
      './public/assets/coffee/select.coffee',
      './public/assets/coffee/default-css.coffee'
    ],
    reservation: [
      './public/assets/coffee/common.coffee',
      './public/assets/coffee/reservation.coffee',
      './public/assets/coffee/reservation-css.coffee'
    ]
  },
  output: {
    filename: '[name].js',
    path: path.resolve(__dirname, 'public', 'assets', 'dist')
  },
  module: {
    rules: [
      {
        test: /\.css$/,
        use: ['style-loader', 'css-loader']
      },
      {
        test: /\.(eot|svg|ttf|woff|woff2|otf)$/,
        use: {
          loader: 'file-loader',
          options: {
            publicPath: '/assets/dist/'
          }
        }
      },
      {
        test: /\.html$/,
        loader: 'handlebars-loader'
      },
      {
        test: /\.coffee$/,
        use: ['coffee-loader']
      },
      {
        test: /\.less$/,
        use: ['style-loader', 'css-loader', 'less-loader']
      }
    ]
  },
  plugins: [
    new webpack.ProvidePlugin({
      $: "jquery",
      jQuery: "jquery",
      _: "underscore"
    }),
    new CleanWebpackPlugin(pathsToClean)
  ]
};

#!/usr/bin/env node

var program = require('commander'),
    baseurl;

program
  .arguments('<baseurl>')
  .option('-o, --outfile <file>', 'a file to output the URL list to')
  .option('-v, --verbose', 'output additional status info')
  .action(function(base) {
    var sitemaps = require('./index'),
        fs = require('fs'), wstream;

    baseurl = base;

    if (program.outfile) {
      wstream = fs.createWriteStream(program.outfile);
    }

    var urlOut = function (url, sitemap) {
        if (wstream) {
          wstream.write(url + "\n");
        }

        if (!wstream || program.verbose) {
          console.log(url);
        }
      },
      done = function (err, sitemaps) {
        if (wstream) {
          wstream.end();
        }

        if (err) {
          console.error(new Error(err));
        } else if (sitemaps && program.verbose) {
          console.error("Parsed sitemaps: " + sitemaps);
        }
      };

    sitemaps.parseSitemaps(base, urlOut, done);
  })
  .parse(process.argv);

if (typeof baseurl === 'undefined') {
  program.help();
}

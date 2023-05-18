got = require 'got'
sax = require 'sax'
async = require 'async'
zlib = require 'zlib'
urlParser = require 'url'
UserAgent = require 'user-agents'


userAgent = new UserAgent [/Chrome/, { platform: 'Win32' }]

headers =
	'user-agent': process.env.USER_AGENT || userAgent().toString();
agentOptions =
	keepAlive: true
	gzip: true
got = got.extend {headers, agentOptions, timeout: 60000}

class SitemapParser
	constructor: (@url_cb, @sitemap_cb, @options) ->
		@visited_sitemaps = {}
		if @options
			got = got.extend @options

	_download: (url, parserStream, error_cb) ->

		if url.lastIndexOf('.gz') is url.length - 3
			stream = got.stream({url, responseType: 'buffer'})
			unzip = zlib.createGunzip()
			finalStream = stream.pipe(unzip).pipe(parserStream)

			stream.on 'error', error_cb
			unzip.on 'error', error_cb
			finalStream.on 'error', error_cb
	
			return finalStream
		else
			stream = got.stream({url, gzip:true})
			finalStream = stream.pipe(parserStream)
			
			stream.on 'error', error_cb
			finalStream.on 'error', error_cb

			return finalStream		
			
	parse: (url, done) =>
		isURLSet = false
		isSitemapIndex = false
		inLoc = false

		@visited_sitemaps[url] = true

		parserStream = sax.createStream false, {trim: true, normalize: true, lowercase: true}
		parserStream.on 'opentag', (node) =>
			inLoc = node.name is 'loc'
			isURLSet = true if node.name is 'urlset'
			isSitemapIndex = true if node.name is 'sitemapindex'
		parserStream.on 'error', (err) =>
			@url_cb null, url, err
			done err
		parserStream.on 'text', (text) =>
			text = urlParser.resolve url, text
			if inLoc
				if isURLSet
					@url_cb text, url
				else if isSitemapIndex
					if @visited_sitemaps[text]?
						console.error "Already parsed sitemap: #{text}"
					else
						@sitemap_cb text
		parserStream.on 'end', () =>
			done null

		@_download url, parserStream, (err) =>
			@url_cb null, url, err
			done err

exports.parseSitemap = (url, url_cb, sitemap_cb, done, options) ->
	parser = new SitemapParser url_cb, sitemap_cb, options
	parser.parse url, done	

exports.parseSitemaps = (urls, url_cb, sitemap_test, done, options) ->
	unless done
		done = sitemap_test
		sitemap_test = undefined

	urls = [urls] unless urls instanceof Array

	sitemap_cb = (sitemap) ->
		should_push = if sitemap_test then sitemap_test(sitemap) else true
		queue.push sitemap if should_push

	parser = new SitemapParser url_cb, sitemap_cb, options

	queue = async.queue parser.parse, 4
	queue.drain = () ->
		done null, Object.keys(parser.visited_sitemaps)
	queue.push urls

exports.parseSitemapsPromise = (urls, url_cb, sitemap_test, options) ->
	new Promise (resolve) ->
		exports.parseSitemaps(urls, url_cb, sitemap_test, resolve, options)

exports.sitemapsInRobots = (url, cb) ->
	got.get url, (err, res, body) ->
		return cb err if err
		return cb "statusCode: #{res.statusCode}" if res.statusCode isnt 200
		matches = []
		body.replace /^Sitemap:\s?([^\s]+)$/igm, (m, p1) ->
			matches.push(p1)
		cb null, matches

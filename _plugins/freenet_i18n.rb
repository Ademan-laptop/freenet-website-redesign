require 'gettext/po'
require 'gettext/po_parser'

# Stolen from rails via stackoverflow
def strip_heredoc(s)
	indentation = s.scan(/^[ \t]*(?=\S)/).min
	indent = indentation ? indentation.size : 0
	s.gsub(/^[ \t]{#{indent}}/, '')
end

class GetTextTag < Liquid::Block
	#include Liquid::StandardFilters

	#def initialize(tag_name, markup, tokens)
	#end
	
	def get_locale(context)
		page = context.registers[:page]

		return page[:locale] || context.registers[:site].config['locale'] || 'en'
	end

	# FIXME there must be a better way to initialize global state
	def get_translation(context)
		#if context.registers[:translations] == nil
			#context.registers[:translations] = {}
		#end

		#locale = self.get_locale(context)

		#if context.registers[:translations][locale] != nil
			#return context.registers[:translations][locale]
		#end

		#site = context.registers[:site]
		#puts "path: #{path}"
		#puts "Page count: ", pages.length
		#page = self.get_page(context)
		#return page['locale']
		#return pages.first.locale

		page = context.registers[:page]
		path = page['path']
		pages = self.get_pages(context)

		page = pages.first

		if defined? page.locale
			return page.locale
		else
			return nil
		end
	end

	def get_pages(context)
		return context.registers[:site].pages.select do |p|
			p.path == context['page']['path']
		end
	end

	def get_page(context)
		self.get_pages(context).first
	end

	def render(context)
		site = context.registers[:site]
		page = context.registers[:page]

		translation = self.get_translation(context)

		contents = super.to_s.gsub(%r!\A\s*(\n|\r)+|(\n|\r)+\s*\z!, "")
		contents = strip_heredoc(contents)

		# TODO probably can be more concise translation[contents] || contents ?
		if translation != nil && translation[contents]
			return translation[contents].msgstr
		else
			return contents
		end

	end
end

class TranslatedPage < Jekyll::Page
	attr_accessor :locale
	def initialize(site, base, dir, name, localized_name, locale_name, locale)
		@localized_name = localized_name
		@locale_name = locale_name
		@locale = locale

		#puts "name: #{name} dir: #{dir}"
		super(site, base, dir, name) #localized_name)
		@name = name
	end

	#def path
	#end

	def template
		if !html?
			#puts "/:path/:basename_:locale:output_ext"
			"/:path/:basename_:locale:output_ext"
		elsif index?
			#puts "/:path_:locale/"
			"/:path_:locale/"
		else
			Jekyll::Utils.add_permalink_suffix("/:path/:basename.:locale", site.permalink_style)
		end
	end

	#def url_placeholders
		#{
			#:path       => @dir,
			#:basename   => basename + "." + @locale_name,
			#:output_ext => output_ext,
			#:locale     => @locale_name
		#}
	#end

	def url
		#puts "trace url()"
		#puts self.url_placeholders()
		#@url ||= Jekyll::URL.new({
			#:template     => template,
			#:placeholders => self.url_placeholders(),
			#:permalink    => permalink
		#}).to_s

		#puts "Path"
		#puts path
		#puts template
		#puts @url
		#return @url
		#
			#:path       => @dir,
			#:basename   => basename + "." + @locale_name,
			#:output_ext => output_ext,
			#:locale     => @locale_name
		#puts @dir
		#puts "path: " + url

		

		url = "/" + basename + "." + @locale_name + "/"
		if @dir != "."
			url = "/" + @dir + url
		end
		return url
	end
	# TODO override url
	#def path
		#return name
	#end
end

class GetTextGenerator < Jekyll::Generator
	def find_translations(site)
		locale_dir = site.config['locale_dir'] || 'locales'
		locales = []
		Dir.foreach(locale_dir).each do |locale_file|
			if locale_file.end_with?('.po')
				parser = GetText::POParser.new()
				translation = GetText::PO.new()

				parser.parse_file(locale_dir + "/" + locale_file, translation)

				extension = File::extname(locale_file)
				basename = File::basename(locale_file, extension)

				locales << [basename, translation]
			end
		end
		return locales
	end

	def generate(site)
		new_pages = []

		self.find_translations(site).each do |locale_name, locale|
			site.pages.each do |page|
				filename = File::basename(page.name)
				extension = File::extname(filename)
				basename = File::basename(filename, extension)

				new_path = basename + '.' + locale_name + extension

				dir = File.dirname(page.path)
				new_pages << TranslatedPage.new(site, site.source, dir, page.name, new_path, locale_name, locale)

				#puts page.name
				#if extension != 'md'
					#continue # FIXME: no continue in ruby?
				#end
				#puts new_path

				#new_pages << TranslatedPage.new(site, page.base, page.dir, new_path)
				#page.base
				#page.dir
				#puts "page.dir: ", page.dir
				#puts "page.path: ", page.path
				# FIXME: I don't think page.dir is correct below
				# FIXME: it is not correct, it is the url dir not the source dir... need to figure this out
				# NOTE: Not certain if dir is correct either, at least suits our purpose
				#puts "url: #{new_pages.last.url}"
			end
		end

		site.pages.concat(new_pages)
	end
end

Liquid::Template.register_tag("gettext", GetTextTag)

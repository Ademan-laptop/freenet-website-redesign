require 'gettext/po'
require 'gettext/po_parser'

# Stolen from rails via stackoverflow
def strip_heredoc(s)
	indentation = s.scan(/^[ \t]*(?=\S)/).min
	indent = indentation ? indentation.size : 0
	s.gsub(/^[ \t]{#{indent}}/, '')
end

def get_pages(context)
	return context.registers[:site].pages.select do |p|
		p.path == context['page']['path']
	end
end

def get_translation(context)
	page = context.registers[:page]
	path = page['path']
	page = get_pages(context).first

	if defined? page.locale
		return page.locale
	else
		return nil
	end
end

class GetTextBlock < Liquid::Block
	def render(context)
		site = context.registers[:site]

		translation = get_translation(context)

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

class GetTextTag < Liquid::Tag
	def initialize(tag_name, text, tokens)
		super
		@text = text
	end

	def render(context)
		site = context.registers[:site]

		translation = get_translation(context)

		contents = strip_heredoc(@text.strip)

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

		super(site, base, dir, name)
	end

	def url
		url = "/" + basename + "." + @locale_name + "/"
		if @dir != "."
			url = "/" + @dir + url
		end
		return url
	end
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
			end
		end

		site.pages.concat(new_pages)
	end
end

Liquid::Template.register_tag("gettext", GetTextBlock)
Liquid::Template.register_tag("gt", GetTextTag)

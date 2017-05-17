#!/usr/bin/env ruby
#encoding: utf-8

require 'psd'

if ARGV.empty?
	puts 'usage: ./psd2html.rb <psd>' 
	exit
end

DEFAULT_FONT_FAMILY = 'Arial, sans-serif'
DEFAULT_FONT_SIZE = '13px'

ENABLE_LAYER_IMAGE = true unless defined? ENABLE_LAYER_IMAGE
ENABLE_LAYER_TEXT = true unless defined? ENABLE_LAYER_TEXT
ENABLE_LAYER_PLACEHOLDER = false unless defined? ENABLE_LAYER_PLACEHOLDER
ENABLE_LAYER_MASK = true unless defined? ENABLE_LAYER_MASK

NAME_POSTFIX = '' unless defined? NAME_POSTFIX

PSD_FILE = ARGV[0]
PSD_NAME = File.basename(PSD_FILE, '.psd') + NAME_POSTFIX
PSD_PNG = PSD_NAME + '.png'
CSS_FILE = PSD_NAME + '.css'
HTML_FILE = PSD_NAME + '.html'
IMAGES_PATH = PSD_NAME + '_images/'

Dir.mkdir IMAGES_PATH unless File.exist? IMAGES_PATH

$usedClasses = {}
$cssStyles = {}

def prepareClassName(str)
	str.gsub(' ', '_').gsub(/[^-_\wа-я]+/ui, '')
end

def makeStyle(styles, separator = ' ')
	styles.map{|k, v| "#{k}: #{v};"}.join(separator)
end

def exportLayer(layer, parent, indent)
	html = ''

	layerClass = prepareClassName(layer.name);

	if layer.folder?
		layerClass = 'l-' + layerClass
	else
		layerClass = 'b-' + layerClass
	end

	if $usedClasses.has_key? layerClass
		for i in 2..99
			unless $usedClasses.has_key? layerClass+"_#{i}"
				layerClass += "_#{i}"
				break
			end
		end
	end

	$usedClasses[layerClass] = true

	layerImageFile = IMAGES_PATH+layerClass+'.png'

	if ENABLE_LAYER_MASK and layer.mask.size > 0 and layer.layer?
		layerStyles = {
			'position' => 'absolute',
			'top' => (layer.mask.top - parent.top).to_s + 'px',
			'left' => (layer.mask.left - parent.left).to_s + 'px',
			'width' => (layer.mask.right - layer.mask.left).to_s + 'px',
			'height' => (layer.mask.bottom - layer.mask.top).to_s + 'px',
			'opacity' => (layer.opacity.to_f / 255).to_s,
			'background-position' => "#{layer.left - layer.mask.left}px #{layer.top - layer.mask.top}px",
			'background-repeat' => 'no-repeat',
		}
	else
		layerStyles = {
			'position' => 'absolute',
			'top' => (layer.top - parent.top).to_s + 'px',
			'left' => (layer.left - parent.left).to_s + 'px',
			'width' => layer.width.to_s + 'px',
			'height' => layer.height.to_s + 'px',
			'opacity' => (layer.opacity.to_f / 255).to_s,
			#'background-position' => 'left top',
			#'background-repeat' => 'no-repeat',
		}
	end

	if layer.hidden?
		layerStyles['display'] = 'none'
	end

	layerTag = 'div'
	layerContent = ''

	if layer.folder?
		#layerStyles['overflow'] = 'hidden';
		
		if ENABLE_LAYER_MASK and layer.mask.size > 0
			layerStyles['clip'] = "rect(#{layer.mask.top - layer.top}px, #{layer.mask.right - layer.left}px, #{layer.mask.bottom - layer.top}px, #{layer.mask.left - layer.left}px)"
		end

		if ENABLE_LAYER_PLACEHOLDER
			layerStyles['background'] = "url(#{PSD_PNG}) no-repeat #{-layer.left}px #{-layer.top}px";	
		end

		layerContent = "\n"+layer.children.reverse.map{|children| exportLayer(children, layer, indent+"\t")}.join+indent
	elsif ENABLE_LAYER_TEXT and layer.text
		color = layer.text[:font][:colors][0]
		
		layerStyles['font-family'] = layer.text[:font][:name] + ', ' + DEFAULT_FONT_FAMILY
		layerStyles['font-size'] = layer.text[:font][:sizes][0].to_s + 'px'
		if color[3] === 255
			layerStyles['color'] = '#%02x%02x%02x' % color
		else
			layerStyles['color'] = "rgba(#{color[0]}, #{color[1]}, #{color[2]}, #{color[3]/255})"
		end

		layerTag = 'span'
		layerContent = "\n\t"+indent+layer.text[:value].gsub("\n", "\n\t"+indent)+"\n"+indent
	elsif ENABLE_LAYER_IMAGE and layer.image
		unless File.exist? layerImageFile
			layer.image.save_as_png layerImageFile
		end

		layerStyles['background-image'] = 'url('+layerImageFile+')';
	else
		return '';
	end

	$cssStyles['.'+layerClass] = makeStyle(layerStyles, "\n\t")
	html += indent+"<#{layerTag} class=\"#{layerClass}\">#{layerContent}</#{layerTag}>\n"

	html
end

PSD.open(PSD_FILE) do |psd|
	psdTree = psd.tree

	psd.image.save_as_png PSD_PNG unless File.exist? PSD_PNG
	#psdTree.save_as_png PSD_NAME+'_build.png' unless File.exist? PSD_NAME+'_build.png'

	$cssStyles['html'] = makeStyle({
		'background' => 'url('+PSD_PNG+') no-repeat center top',
	}, "\n\t")

	$cssStyles['body'] = makeStyle({
		'position' => 'relative',
		'margin' => '0 auto',
		'width' => psd.width.to_s + 'px',
	}, "\n\t")

	File.open(HTML_FILE, 'w') do |html|
		html.puts '<!DOCTYPE html>'
		html.puts '<html>'
		html.puts '<head>'
		html.puts "\t"+'<meta charset="utf-8">'
		html.puts "\t"+'<link rel="stylesheet" href="'+CSS_FILE+'">'
		html.puts '</head>'
		html.puts '<body>'
		
		psdTree.children.reverse.each do |layer|
			html.puts exportLayer(layer, psdTree, "\t")
		end

		html.puts '</body>'
		html.puts '</html>'
	end

	File.open(CSS_FILE, 'w') do |css|
		$cssStyles.each do |selector, style|
			css.puts "#{selector} {\n\t#{style}\n}\n"
		end
	end
end
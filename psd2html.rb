#!/usr/bin/env ruby
#encoding: utf-8

require 'psd'

if ARGV.empty?
	puts 'usage: ./psd2html.rb <psd>' 
	exit
end

DEFAULT_FONT_FAMILY = 'Arial, sans-serif'
DEFAULT_FONT_SIZE = '13px'

ENABLE_LAYER_PLACEHOLDER = false
ENABLE_MASK = true

PSD_FILE = ARGV[0]
PSD_NAME = File.basename(PSD_FILE, '.psd')
PSD_PNG = PSD_NAME + '.png'
HTML_FILE = PSD_NAME + '.html'
IMAGES_PATH = PSD_NAME + '_images/'

Dir.mkdir IMAGES_PATH unless File.exist? IMAGES_PATH

def prepareClassName(str)
	str.gsub(' ', '_').gsub(/[^-_\wа-я]+/ui, '')
end

def makeStyle(styles)
	styles.map{|k, v| "#{k}: #{v};"}.join
end

$usedClasses = {}

def exportLayer(layer, parent, indent)
	html = ''

	layerClass = prepareClassName(layer.name);

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

	if ENABLE_MASK and layer.mask.size > 0 and layer.layer?
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

	if layer.folder?
		#layerStyles['overflow'] = 'hidden';
		
		if ENABLE_MASK and layer.mask.size > 0
			layerStyles['clip'] = "rect(#{layer.mask.top - layer.top}px, #{layer.mask.right - layer.left}px, #{layer.mask.bottom - layer.top}px, #{layer.mask.left - layer.left}px)"
		end

		if ENABLE_LAYER_PLACEHOLDER
			layerStyles['background'] = "url(#{PSD_PNG}) no-repeat #{-layer.left}px #{-layer.top}px";	
		end
		html += indent+'<div class="l-'+layerClass+'" style="'+makeStyle(layerStyles)+'">'+"\n"
		
		layer.children.reverse.each do |children|
			html += exportLayer(children, layer, indent+"\t")
		end

		html += indent+"</div>"+"\n"
	elsif layer.text
		#p layer.text[:font]
		#layerFont = layer.text[:font][:css].gsub('pt', 'px')
		color = layer.text[:font][:colors][0]
		layerFont = makeStyle({
			'font-family' => layer.text[:font][:name] + ', ' + DEFAULT_FONT_FAMILY,
			'font-size' => layer.text[:font][:sizes][0].to_s + 'px',
			'color' => "rgba(#{color[0]}, #{color[1]}, #{color[2]}, #{color[3]/255})",
		})
		html += indent+'<div class="b-'+layerClass+'" style="'+makeStyle(layerStyles)+layerFont+'">'+layer.text[:value]+'</div>'+"\n"
	elsif layer.image
		unless File.exist? layerImageFile
			layer.image.save_as_png layerImageFile
		end

		layerStyles['background-image'] = 'url('+layerImageFile+')';
		html += indent+'<div class="b-'+layerClass+'" style="'+makeStyle(layerStyles)+'"></div>'+"\n"
	end

	html
end

PSD.open(PSD_FILE) do |psd|
	psdTree = psd.tree

	psd.image.save_as_png PSD_PNG unless File.exist? PSD_PNG
	#psdTree.save_as_png PSD_NAME+'_build.png' unless File.exist? PSD_NAME+'_build.png'

	File.open(HTML_FILE, 'w') do |html|
		htmlStyles = {
			'background' => 'url('+PSD_PNG+') no-repeat center top',
		}

		bodyStyles = {
			'position' => 'relative',
			'margin' => '0 auto',
			'width' => psd.width.to_s + 'px',
			#'height' => psd.height.to_s + 'px',
		}

		html.puts '<!DOCTYPE html>'
		html.puts '<html style="'+makeStyle(htmlStyles)+'">'
		html.puts '<head>'
		html.puts "\t"+'<meta charset="utf-8">'
		html.puts '</head>'
		html.puts '<body style="'+makeStyle(bodyStyles)+'">'
		
		psdTree.children.reverse.each do |layer|
			html.puts exportLayer(layer, psdTree, "\t")
		end

		html.puts '</body>'
		html.puts '</html>'

		#p psd.tree
		#p $usedClasses.select{|k,v| v > 1}
	end
end
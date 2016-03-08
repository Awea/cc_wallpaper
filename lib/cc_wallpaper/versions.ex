defmodule Mix.Tasks.CcWallpaper do
  use Mix.Task

  defmodule DominantColor do
    @shortdoc "Output dominant image color"

    def run(_) do
      # width: 1022 height: 1392
      output   = :os.cmd('convert #{System.cwd()}/datas/portrait.jpg -format %c -depth 8  histogram:info: | sort -n | tail -1') |> to_string 
      # => '686750: (228,227,222) #E4E3DE srgb(228,227,222)'
      hexColor = Regex.run(~r/#([0-9A-Z]*)/, output) |> List.last
      # => "E4E3DE"
      # list to integer: https://github.com/rjsamson/hexate/blob/master/lib/hexate.ex

      IO.inspect(hexColor)
    end
  end

  # http://is.gd/cnVn4D
  # rules:
  # * watermark only on landscapes images
  # * light and dark watermark related to image brightness
  # * jpeg quality equivalent
  # * multiple image sizes related to input image size

  # landscape resise and watermak uses:
  # 1280×800 : utiliser le watermark avec une hauteur de 13px
  # 1440×900 : utiliser le watermark avec une hauteur de 13px
  # 1680×1050 : utiliser le watermark avec une hauteur de 13px
  # 1920×1200 : utiliser le watermark avec une hauteur de 13px
  # 2560×1440 : utiliser le watermark avec une hauteur de 13px
  # 3840×2400 : utiliser le watermark avec une hauteur de 22px
  # portrait resize:
  # iPhone 5 (640x1136)
  # iPhone 6 (750x1334)
  # iPhone 6plus (1080x1920)
  # square:
  # iPad (2048x2048)
  defmodule WaterMark do
    import Mogrify

    @shortdoc "Add a watermark to an image"

    @desktop_sizes %{desktop_a: "1280x800", desktop_b: "1440x900", desktop_c: "1680x1050", desktop_d: "1920x1200", desktop_e: "2560x1440", desktop_f: "3840x2400"}
    @iphone_sizes %{iphone_5: "640x1136", iphone_6: "750x1334", iphone_6_plus: "1080x1920"}
    @ipad_sizes %{ipad: "2048x2048"}

    def run(args) do
      # http://is.gd/TWGGvC
      {opts, _, _} = OptionParser.parse(args, aliases: [p: :path], strict: [path: :string]) 
      image_path   = opts[:path]

      image              = open(image_path)
      image_infos        = image |> verbose
      image_dirname      = image_infos.path |> Path.dirname
      output_dirname     = "#{image_dirname}/output"
      output_basename    = image_infos.path |> Path.basename(image_infos.ext)
      {sizes, watermark} = output_basename |> get_sizes

      unless File.exists?(output_dirname) do
        File.mkdir(output_dirname)
      end

      Enum.filter(sizes, fn{_, size} -> 
        size = String.replace(size, "x", "")
        String.to_integer(size) <= String.to_integer("#{image_infos.width}#{image_infos.height}")
      end)
      |> Enum.each(fn{k, size} -> 
        new_file_name  = "#{file_name_convention(output_basename, k, size, image_infos.ext)}"
        new_image_path = "#{output_dirname}/#{file_name_convention(output_basename, k, size, image_infos.ext)}"
        
        image |> copy |> resize_to_fill(size) |> save(new_image_path) 

        # add a watermark
        if watermark do
          args = ~w(-gravity SouthWest #{System.cwd()}/datas/watermarks/watermark-height-#{watermark_size(size)}-dark.png #{new_image_path} #{new_image_path})
          System.cmd "composite", args, stderr_to_stdout: true
        end
      end)
    end

    defp watermark_size(size) do
      if size == "3840x2400" do
        "22px"
      else
        "13px"
      end
    end

    defp file_name_convention(basename, device, size, ext) do
      device = device |> Atom.to_string
      cond do
        String.contains? device, "iphone"->
          basename = String.replace(basename, ~r/-wallpaper-(.*)/, "")
          "#{basename}-wallpaper-#{String.replace(device, "_", "-")}#{ext}"
        String.contains? device, "ipad" ->
          "#{basename}#{ext}"
        true ->
          basename = String.replace(basename, ~r/-wallpaper-(.*)/, "")
          "#{basename}-wallpaper-#{size}#{ext}"
      end
    end

    defp get_sizes(basename) do
      cond do
        String.contains? basename, "iphone" ->
          {@iphone_sizes, false}
        String.contains? basename, "ipad" ->
          {@ipad_sizes, false}
        true ->
          {@desktop_sizes, true}
      end
    end
  end
end
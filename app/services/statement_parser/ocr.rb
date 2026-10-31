# Text recognition for photos and scanned PDFs with Tesseract, a free program that runs locally.
# Scanned PDFs are first turned into images with pdftoppm (poppler-utils).
module StatementParser::Ocr
  INSTALL_HINT = "sudo apt install tesseract-ocr tesseract-ocr-por poppler-utils"

  def self.image(bytes)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "statement")
      File.binwrite(path, bytes)
      recognize(path)
    end
  end

  def self.pdf(bytes)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "statement.pdf")
      File.binwrite(path, bytes)
      run!("pdftoppm", "-r", "300", "-png", path, File.join(dir, "page"))
      Dir[File.join(dir, "page*.png")].sort.map { |page| recognize(page) }.join("\n\f\n")
    end
  end

  def self.recognize(path)
    # --psm 6 reads the image as one block of text, which keeps table rows on a single line
    run!("tesseract", path, "stdout", "-l", languages, "--psm", "6")
  end

  # Portuguese when its language pack is installed (tesseract-ocr-por)
  def self.languages
    run!("tesseract", "--list-langs").lines.map(&:strip).include?("por") ? "por" : "eng"
  end

  # Returns the command's standard output (Tesseract writes progress messages to stderr)
  def self.run!(*command)
    output, _errors, status = Open3.capture3(*command)
    raise StatementParser::Error, "Não foi possível ler o texto do arquivo." unless status.success?

    output
  rescue Errno::ENOENT
    raise StatementParser::Error,
      "Para ler fotos e PDFs escaneados é preciso instalar o Tesseract, gratuito: #{INSTALL_HINT}"
  end
end

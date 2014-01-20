module PigSpec
  require 'fileutils'
  INPUT_DIR_PREFIX = "pig_test_"
  PIG_CMD_PREFIX = "pig"

  attr_reader :output_files, :input_dir, :error_stream, :stdout_stream, :exit_code
  @@test_number = 0

  def initialize
    @output_files = {}
    @input_dir = ""
    @error_stream = $stderr
    @stdout_stream = $stdout
    @exit_code = 0
  end

  def self.test_number
    @@test_number
  end

  def test_pig_script(pig_binary, pig_script, input_files_hash, output_files_hash, params)
    @error_stream = error_stream
    @stdout_stream = stdout_stream
    @@test_number = @@test_number + 1

    write_input_files(input_files_hash)
    @output_files = output_files_hash
    run_script(pig_binary, pig_script, params)
  end

  def build_pig_script_params(params)
    if params.class != Hash
      error_stream.puts "Params had unexpected class: #{params.class}"
      return ""
    end

    params.reduce("") do |param_str, param|
      param_str + (param_str.empty? ? "" : " ") + "-p " + param[0].to_s + "=" + param[1].to_s
    end
  end

  def build_cmd_line(pig_binary, pig_script, params)
    pig_params = build_pig_script_params(params)
    pig_params = pig_params.empty? ? "" : "#{pig_params} "
    "#{PIG_CMD_PREFIX} #{pig_params}#{pig_script}"
  end

  def run_script(pig_binary, pig_script, params)
    cmd_to_run = build_cmd_line(pig_binary, pig_script, params)
    stdout_stream.puts("Running the following command: #{cmd_to_run}")
    original_cwd = Dir.pwd
    Dir.chdir(input_dir)
    system cmd_to_run
    @exit_code = $?
    if exit_code != 0
      error_stream.puts "Pig script exited with non-zero exit code: #{exit_code}."
    end
    Dir.chdir(original_cwd)
  end

  def write_input_files(input_files_hash)
    @input_dir = File.expand_path(INPUT_DIR_PREFIX + PigSpec.test_number.to_i.to_s)

    FileUtils.rm_rf(input_dir)
    FileUtils.mkdir_p(input_dir)

    if input_files_hash.class != Hash
      error_stream.puts "Input files had unexpected class: #{input_files_hash.class}"
      return
    end

    input_files_hash.keys.each do |file_name|
      File.open(File.join(input_dir, file_name.to_s), "w") { |f| f.print(input_files_hash[file_name]) }
    end
  end

  def print_mismatch_error(file)
    error_stream.puts "Mismatch detected in '#{file}':"
  end

  def compare_pairs(file, pairs, mapping)
    pairs.each do |pair|
      if pair[0] != pair[1]
        print_mismatch_error(file)
        error_stream.puts "\tExpected line: '#{pair[mapping[:expected]]}'"
        error_stream.puts "\tActual line:   '#{pair[mapping[:actual]]}'"
        return false
      end
    end
  end

  def verify_output(order_matters)
    stdout_stream.puts "----------------------------------"
    stdout_stream.puts "| Verifying Pig script output... |"
    stdout_stream.puts "----------------------------------"
    if output_files.class != Hash
      error_stream.puts "Expected hash of expected output with (filename, file content) pairs. Unexpected class: #{output_files.class}"
      return false
    elsif output_files.size == 0
      error_stream.puts "No output files to verify."
      return false
    end

    if exit_code != 0
      error_stream.puts "Pig script exited with non-zero exit code: #{exit_code}."
      return false
    end

    all_output_matched = true
    original_cwd = Dir.pwd
    Dir.chdir(input_dir)

    output_files.keys.each do |file|
      file_lines_array = IO.read(file).split("\n")
      file_lines_array = file_lines_array.sort if !order_matters

      expected_output_array = output_files[file].split("\n")
      expected_output_array = expected_output_array.sort if !order_matters

      if (!compare_pairs(file, expected_output_array.zip(file_lines_array), { :expected => 0, :actual => 1 }) ||
          !compare_pairs(file, file_lines_array.zip(expected_output_array), { :expected => 1, :actual => 0 }))
        all_output_matched = false
        next
      end
    end

    Dir.chdir(original_cwd)
    all_output_matched
  end
end

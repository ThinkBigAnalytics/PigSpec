require 'spec_helper'
require 'pig-spec/pig_unit_core'

class DummyPigSpec
  include PigSpec
end

describe PigSpec do
  subject { DummyPigSpec.new }

  let(:pig_binary)      { "pig-0.6.0-core.jar" }
  let(:script_name)     { "test.pig" }
  let(:input_hash)      { {"foo.txt" => "bar"} }
  let(:output_hash)     { {:foo => "baz"} }
  let(:params)          { {:param1 => "baz"} }
  let(:unique_spec_dir) { PigSpec::INPUT_DIR_PREFIX.to_s + PigSpec.test_number.to_s }
  let(:mock_stdout)     { mock }
  let(:mock_stderr)     { mock }

  before do
    # Stub out stdout and stderr for tests where they are not relevant
    subject.stub(:stdout_stream => mock_stdout)
    mock_stdout.stub(:puts)

    subject.stub(:error_stream => mock_stderr)
    mock_stderr.stub(:puts)
  end

  def generate_unique_str
    Time.now.to_f.to_s.gsub(".", "_")
  end

  describe '#test_pig_script' do
    before do
      subject.stub(:write_input_files)
      subject.stub(:run_script)
    end

    it "should call the run_script method with the appropriate command line parameters" do
      subject.should_receive(:run_script).with(pig_binary, script_name, params)
      subject.test_pig_script(pig_binary, script_name, input_hash, output_hash, params)
    end

    it "should call the write_input_files method" do
      subject.should_receive(:write_input_files).with(input_hash)
      subject.test_pig_script(pig_binary, script_name, input_hash, output_hash, params)
    end

    it "should store the expected output files in an instance variable" do
      subject.test_pig_script(pig_binary, script_name, input_hash, output_hash, params)
      subject.output_files.should == output_hash
    end

    it "should increment the test number" do
      prev_test_number = PigSpec.test_number
      subject.test_pig_script(pig_binary, script_name, input_hash, output_hash, params)
      PigSpec.test_number.should == prev_test_number + 1
    end
  end

  describe '#write_input_files' do
    before do
      PigSpec.stub(:test_number).and_return(Time.now.to_i)
      FileUtils.rm_rf(unique_spec_dir) if File.exists?(unique_spec_dir)
    end

    after do
      FileUtils.rm_rf(unique_spec_dir) if File.exists?(unique_spec_dir)
    end

    let(:input_files)     { {} }

    context "when a temporary output directory does not already exist" do
      it "should create a temporary directory using the test number" do
        subject.write_input_files(input_files)
        File.directory?(unique_spec_dir).should == true
      end
    end

    context "when a temporary output directory already exists" do
      before do
        FileUtils.mkdir_p(unique_spec_dir)
        File.open(File.join(unique_spec_dir, generate_unique_str + ".txt"), "w") { |f| f.print("hello world") }
      end

      it "should delete the existing directory contents" do
        Dir.glob(File.join(unique_spec_dir, "*")).size.should > 0
        subject.write_input_files(input_files)
        Dir.glob(File.join(unique_spec_dir, "*")).size.should == 0
      end
    end

    context "when the hash of input files is not empty" do
      let(:input_files) { { "foo_#{generate_unique_str}.txt" => generate_unique_str,
                            "bar_#{generate_unique_str}.txt" => generate_unique_str } }

      it "should create one file per hash key and use the hash keys as the filename and hash values as the content" do
        subject.write_input_files(input_files)

        input_files.keys.each do |file_name|
          file_path = File.join(unique_spec_dir, file_name)
          File.exists?(file_path).should == true
          IO.readlines(file_path).join("").should == input_files[file_name]
        end
      end
    end

    context "when the paramter is not a hash" do
      let(:input_files) { nil }
      before do
        input_files.class.should_not == Hash
      end

      it "should print an error and return an empty string" do
        subject.should_receive(:error_stream).and_return(mock_stderr)
        mock_stderr.should_receive(:puts).with("Input files had unexpected class: #{input_files.class}")

        subject.write_input_files(input_files)
      end
    end
  end

  describe '#build_pig_script_params' do
    context "when at least one paramter exists" do
      let(:params) { {"foo" => 123, "bAr" => "234"} }
      it "should create a string where the hash keys are the parameter names and the parameter values are the hash values" do
        subject.build_pig_script_params(params).should == "-p foo=123 -p bAr=234"
      end
    end

    context "when the hash of paramters is empty" do
      let(:params) { {} }
      it "should return an empty string" do
        subject.build_pig_script_params(params).should == ""
      end
    end

    context "when the paramter is not a hash" do
      let(:params) { nil }
      before do
        params.class.should_not == Hash
      end

      it "should print an error and return an empty string" do
        subject.should_receive(:error_stream).and_return(mock_stderr)
        mock_stderr.should_receive(:puts).with("Params had unexpected class: #{params.class}")

        subject.build_pig_script_params(params).should == ""
      end
    end
  end

  describe '#build_cmd_line' do
    it "should call the build_pig_script_params helper method" do
      subject.should_receive(:build_pig_script_params).with(params).and_return("-p fake=fake_value")
      subject.build_cmd_line(pig_binary, script_name, params)
    end

    it "should build a string which joins a standard prefix with the flattened pig parameters and pig script name" do
      subject.build_cmd_line(pig_binary, script_name, params).should == "#{PigSpec::PIG_CMD_PREFIX}#{pig_binary} -x local -p param1=baz #{script_name}"
    end

    context "when there are no Pig script parameters" do
      let(:params) { {} }
      it "should build a script which joins a standard prefix and the pig script name" do
        subject.build_cmd_line(pig_binary, script_name, params).should == "#{PigSpec::PIG_CMD_PREFIX}#{pig_binary} -x local #{script_name}"
      end
    end
  end

  describe '#run_script' do
    before do
      Dir.stub(:chdir)
    end

    it "should call the build_cmd_line helper method" do
      subject.should_receive(:build_cmd_line).with(pig_binary, script_name, params).and_return("true")
      subject.run_script(pig_binary, script_name, params)
    end

    it "should print the command that it is running to stdout" do
      subject.stub(:build_cmd_line => 'true')
      mock_stdout.should_receive(:puts).with("Running the following command: true")
      subject.run_script(pig_binary, script_name, params)
    end

    def echo_string_to_unique_file(base_dir)
      unique_str = generate_unique_str
      unique_filename = File.join(base_dir, "temp_" + unique_str + ".txt")
      FileUtils.rm_rf(unique_filename) if File.exists?(unique_filename)

      subject.stub(:build_cmd_line => 'echo "' + unique_str + '" > ' + unique_filename)

      subject.run_script(pig_binary, script_name, params)
      File.exists?(unique_filename).should == true
      IO.readlines(unique_filename).join("") == unique_str

      FileUtils.rm_rf(unique_filename)
    end

    it "should run the string returned by the build_cmd_line helper method" do
      unique_filename = echo_string_to_unique_file(File.expand_path("."))
    end

    context "when the command fails" do
      it "should print an error message with the appropriate exit code" do
        subject.stub(:build_cmd_line => 'false')
        system 'false'
        false_exit_code = $?

        subject.should_receive(:error_stream).and_return(mock_stderr)
        mock_stderr.should_receive(:puts).with("Pig script exited with non-zero exit code: #{false_exit_code}.")

        subject.exit_code.should == 0
        subject.run_script(pig_binary, script_name, params)
        subject.exit_code.should == false_exit_code
      end
    end

    it "should run the command within the temporary directory created for this test" do
      original_cwd = Dir.pwd
      unique_dir = File.expand_path(FileUtils.mkdir_p(generate_unique_str))
      subject.should_receive(:input_dir).and_return(unique_dir)

      unique_filename = echo_string_to_unique_file(unique_dir)
      Dir.pwd.should == original_cwd

      FileUtils.rm_rf(unique_dir)
    end
  end

  describe '#verify_output' do
    let(:order_matters)  { true }

    it "should print a standard message letting the user know that it's about to start verifying output" do
      mock_stdout.should_receive(:puts).with("----------------------------------")
      mock_stdout.should_receive(:puts).with("| Verifying Pig script output... |")
      mock_stdout.should_receive(:puts).with("----------------------------------")
      subject.verify_output(order_matters)
    end

    context "when there is no expected output" do
      before do
        subject.stub(:output_files).and_return( {} )
      end

      it "should print an error message and return false" do
        subject.should_receive(:error_stream).and_return(mock_stderr)
        mock_stderr.should_receive(:puts).with("No output files to verify.")
        subject.verify_output(order_matters).should == false
      end
    end

    context "when the expected output is not a hash" do
      before do
        subject.stub(:output_files).and_return( nil )
      end

      it "should return false and print an error message" do
        subject.should_receive(:error_stream).and_return(mock_stderr)
        mock_stderr.should_receive(:puts).with("Expected hash of expected output with (filename, file content) pairs. Unexpected class: #{nil.class}")
        subject.verify_output(order_matters).should == false
      end
    end

    context "when there is one or more output files to compare and there are no type errors" do
      let(:file_paths)       { [File.join(generate_unique_str + ".txt"),
                                File.join(generate_unique_str + ".txt")] }
      let(:file_contents)    { ["hello world\ngoodbye world\nhi world\nhey world\nlater world\nbye world\n",
                                "hello universe\ngoodbye universe\nhi universe\nhey universe\nlater universe\nbye universe"] }
      let(:actual_output)    { Hash[*file_paths.zip(file_contents).flatten] }
      let(:reordered_output) { actual_output.merge( {file_paths[0] => file_contents[0].split("\n").sort.join("\n")} ) }

      before do
        subject.stub(:input_dir).and_return(generate_unique_str)
        FileUtils.mkdir_p(subject.input_dir)

        actual_output.keys.each do |file_path|
          File.open(File.join(subject.input_dir, file_path), "w") { |f| f.print(actual_output[file_path]) }
        end

        subject.stub(:output_files).and_return( actual_output )

        reordered_output.should_not == actual_output
      end

      after do
        FileUtils.rm_rf(subject.input_dir) if File.exists?(subject.input_dir)
      end

      it "should return false when the Pig script exits with a non-zero exit code" do
        subject.stub(:exit_code).and_return(123)
        subject.should_receive(:error_stream).and_return(mock_stderr)
        mock_stderr.should_receive(:puts).with("Pig script exited with non-zero exit code: 123.")
        subject.verify_output(order_matters).should == false
      end

      context "when the actual output has one or more lines than the expected output" do
        let(:mismatch) { actual_output[file_paths[0]].split("\n")[0..-2].join("\n") }
        before do
          subject.stub(:output_files).and_return( actual_output.merge( file_paths[0] => mismatch ) )
        end
        it "should print the first extra line and return false" do
          subject.should_receive(:error_stream).and_return(mock_stderr)
          mock_stderr.should_receive(:puts).with("Mismatch detected in '#{file_paths[0]}':")
          mock_stderr.should_receive(:puts).with("\tExpected line: ''")
          mock_stderr.should_receive(:puts).with("\tActual line:   '#{actual_output[file_paths[0]].split("\n")[-1]}'")
          subject.verify_output(order_matters).should == false
        end
      end

      context "when the expected output has one or more lines than the actual output" do
        let(:mismatch) { actual_output[file_paths[0]] + "extra line\n" }
        before do
          subject.stub(:output_files).and_return( actual_output.merge( file_paths[0] => mismatch ) )
        end
        it "should print the first extra line and return false" do
          subject.should_receive(:error_stream).and_return(mock_stderr)
          mock_stderr.should_receive(:puts).with("Mismatch detected in '#{file_paths[0]}':")
          mock_stderr.should_receive(:puts).with("\tExpected line: '#{mismatch.split("\n")[-1]}'")
          mock_stderr.should_receive(:puts).with("\tActual line:   ''")
          subject.verify_output(order_matters).should == false
        end
      end

      context "when output order matters" do
        let(:order_matters)  { true }

        context "when the output is exactly the same as the file contents" do
          it "should return true" do
            subject.verify_output(order_matters).should == true
          end
        end

        context "when the output is not exactly the same as the file contents" do
          before do
            subject.stub(:output_files).and_return( reordered_output )
          end

          it "should return false" do
            subject.should_receive(:error_stream).and_return(mock_stderr)
            mock_stderr.should_receive(:puts).with("Mismatch detected in '#{file_paths[0]}':")
            mock_stderr.should_receive(:puts).with("\tExpected line: '#{reordered_output[file_paths[0]].split("\n")[0]}'")
            mock_stderr.should_receive(:puts).with("\tActual line:   '#{actual_output[file_paths[0]].split("\n")[0]}'")
            subject.verify_output(order_matters).should == false
          end
        end
      end

      context "when output order doesn't matter" do
        let(:order_matters) { false }

        context "when expected output contains the same lines as the file, but in a different order" do
          before do
            subject.stub(:output_files).and_return( reordered_output )
          end

          it "should return true" do
            subject.verify_output(order_matters).should == true
          end
        end

        context "when expected output does not contain the same lines as the file" do
          let(:mismatch) { reordered_output[file_paths[0]] + "2" }
          before do
            subject.stub(:output_files).and_return( reordered_output.merge( file_paths[0] => mismatch ) )
          end
          it "should return false" do
            subject.should_receive(:error_stream).and_return(mock_stderr)
            mock_stderr.should_receive(:puts).with("Mismatch detected in '#{file_paths[0]}':")
            mock_stderr.should_receive(:puts).with("\tExpected line: '#{mismatch.split("\n")[-1]}'")
            mock_stderr.should_receive(:puts).with("\tActual line:   '#{mismatch[0, mismatch.size - 1].split("\n")[-1]}'")
            subject.verify_output(order_matters).should == false
          end
        end
      end
    end
  end
end

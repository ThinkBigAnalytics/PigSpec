PigSpec README
==============
*Copyright (C) 2010-2014 Think Big Analytics, Inc. All Rights Reserved.*

Summary/Description
===================
PigSpec is a Ruby gem which can be used to test Pig scripts.  It was designed to be easily integrated with the RSpec framework.  It is loosely based on PigUnit (see: https://pig.apache.org/docs/r0.8.1/pigunit.html).

Building the gem:
-----------------
The PigSpec gem can be built with the following command:

```bash
gem build pig-spec.gemspec
```

Example usage:
--------------
```ruby
require 'pig-spec'

describe 'something to be tested' do
  include PigSpec

  it 'should run the pig script and produce a single line of output' do
    test_pig_script 'pig-0.6.0-core.jar', 'fake_script.pig', { "generated_file.txt" => "PigSpec creates this file. Current time is: #{Time.now}" }, { "output.csv" => "1,2,3,4" }, { "param1" => "foo", "param2" => "bar" }
    verify_output(false).should == true
  end
end
```

If PigSpec is properly installed, you will see the following line (along with standard RSpec output) when the spec is run:

>Running the following command: java -jar pig-0.6.0-core.jar -x local -p param1=foo -p param2=bar fake_script.pig

Unless you've made some modifications to the above example (e.g. pointing it to an actual Pig JAR & script on your system), the above example will fail and produce output that looks like:

>Running the following command: java -jar pig-0.6.0-core.jar -x local -p param1=foo -p param2=bar fake_script.pig  
>Unable to access jarfile pig-0.6.0-core.jar  
>Pig script exited with non-zero exit code: 256.  
>\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
>| Verifying Pig script output... |  
>\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
>Pig script exited with non-zero exit code: 256.  
>F
>
>Failures:
>
>  1) something to be tested should run the pig script and produce a single line of output  
>     Failure/Error: verify_output(false).should == true  
>       expected: true  
>            got: false (using ==)  
>     # ./spec/example_spec.rb:8
>
>Finished in 0.0131 seconds  
>1 example, 1 failure
>
>Failed examples:
>
>rspec ./spec/example_spec.rb:6 # something to be tested should run the pig script and produce a single line of output

$:.unshift File.dirname(__FILE__) + "/../../lib"

require 'test/unit'
require 'action_controller/cgi_ext/cgi_methods'
require 'stringio'

class CGITest < Test::Unit::TestCase
  def setup
    @query_string = "action=create_customer&full_name=David%20Heinemeier%20Hansson&customerId=1"
    @query_string_with_nil = "action=create_customer&full_name="
    @query_string_with_array = "action=create_customer&selected[]=1&selected[]=2&selected[]=3"
    @query_string_with_amps  = "action=create_customer&name=Don%27t+%26+Does"
    @query_string_with_multiple_of_same_name = 
      "action=update_order&full_name=Lau%20Taarnskov&products=4&products=2&products=3"
    @query_string_with_many_equal = "action=create_customer&full_name=abc=def=ghi"
    @query_string_without_equal = "action"
    @query_string_with_many_ampersands =
      "&action=create_customer&&&full_name=David%20Heinemeier%20Hansson"
  end

  def test_query_string
    assert_equal(
      { "action" => "create_customer", "full_name" => "David Heinemeier Hansson", "customerId" => "1"},
      CGIMethods.parse_query_parameters(@query_string)
    )
  end
  
  def test_deep_query_string
    assert_equal({'x' => {'y' => {'z' => '10'}}}, CGIMethods.parse_query_parameters('x[y][z]=10'))
  end
  
  def test_deep_query_string_with_array
    assert_equal({'x' => {'y' => {'z' => ['10']}}}, CGIMethods.parse_query_parameters('x[y][z][]=10'))
    assert_equal({'x' => {'y' => {'z' => ['10', '5']}}}, CGIMethods.parse_query_parameters('x[y][z][]=10&x[y][z][]=5'))
  end
  
  def test_query_string_with_nil
    assert_equal(
      { "action" => "create_customer", "full_name" => nil},
      CGIMethods.parse_query_parameters(@query_string_with_nil)
    )
  end

  def test_query_string_with_array
    assert_equal(
      { "action" => "create_customer", "selected" => ["1", "2", "3"]},
      CGIMethods.parse_query_parameters(@query_string_with_array)
    )
  end

  def test_query_string_with_amps
    assert_equal(
      { "action" => "create_customer", "name" => "Don't & Does"},
      CGIMethods.parse_query_parameters(@query_string_with_amps)
    )    
  end
  
  def test_query_string_with_many_equal
    assert_equal(
      { "action" => "create_customer", "full_name" => "abc=def=ghi"},
      CGIMethods.parse_query_parameters(@query_string_with_many_equal)
    )    
  end
  
  def test_query_string_without_equal
    assert_equal(
      { "action" => nil },
      CGIMethods.parse_query_parameters(@query_string_without_equal)
    )    
  end

  def test_query_string_with_many_ampersands
    assert_equal(
      { "action" => "create_customer", "full_name" => "David Heinemeier Hansson"},
      CGIMethods.parse_query_parameters(@query_string_with_many_ampersands)
    )
  end

  def test_parse_params
    input = {
      "customers[boston][first][name]" => [ "David" ],
      "customers[boston][first][url]" => [ "http://David" ],
      "customers[boston][second][name]" => [ "Allan" ],
      "customers[boston][second][url]" => [ "http://Allan" ],
      "something_else" => [ "blah" ],
      "something_nil" => [ nil ],
      "something_empty" => [ "" ],
      "products[first]" => [ "Apple Computer" ],
      "products[second]" => [ "Pc" ]
    }
    
    expected_output =  {
      "customers" => {
        "boston" => {
          "first" => {
            "name" => "David",
            "url" => "http://David"
          },
          "second" => {
            "name" => "Allan",
            "url" => "http://Allan"
          }
        }
      },
      "something_else" => "blah",
      "something_empty" => "",
      "something_nil" => "",
      "products" => {
        "first" => "Apple Computer",
        "second" => "Pc"
      }
    }

    assert_equal expected_output, CGIMethods.parse_request_parameters(input)
  end
  
  def test_parse_params_from_multipart_upload
    mockup = Struct.new(:content_type, :original_filename)
    file = mockup.new('img/jpeg', 'foo.jpg')
    ie_file = mockup.new('img/jpeg', 'c:\\Documents and Settings\\foo\\Desktop\\bar.jpg')
  
    input = {
      "something" => [ StringIO.new("") ],
      "array_of_stringios" => [[ StringIO.new("One"), StringIO.new("Two") ]],
      "mixed_types_array" => [[ StringIO.new("Three"), "NotStringIO" ]],
      "mixed_types_as_checkboxes[strings][nested]" => [[ file, "String", StringIO.new("StringIO")]],
      "ie_mixed_types_as_checkboxes[strings][nested]" => [[ ie_file, "String", StringIO.new("StringIO")]],
      "products[string]" => [ StringIO.new("Apple Computer") ],
      "products[file]" => [ file ],
      "ie_products[string]" => [ StringIO.new("Microsoft") ],
      "ie_products[file]" => [ ie_file ]
    }
    
    expected_output =  {
      "something" => "",
      "array_of_stringios" => ["One", "Two"],
      "mixed_types_array" => [ "Three", "NotStringIO" ],
      "mixed_types_as_checkboxes" => {
         "strings" => {
            "nested" => [ file, "String", "StringIO" ]
         },
      },
      "ie_mixed_types_as_checkboxes" => {
         "strings" => {
            "nested" => [ ie_file, "String", "StringIO" ]
         },
      },
      "products" => {
        "string" => "Apple Computer",
        "file" => file
      },
      "ie_products" => {
        "string" => "Microsoft",
        "file" => ie_file
      }
    }

    params = CGIMethods.parse_request_parameters(input)
    assert_equal expected_output, params

    # Lone filenames are preserved.
    assert_equal 'foo.jpg', params['mixed_types_as_checkboxes']['strings']['nested'].first.original_filename
    assert_equal 'foo.jpg', params['products']['file'].original_filename

    # But full Windows paths are reduced to their basename.
    assert_equal 'bar.jpg', params['ie_mixed_types_as_checkboxes']['strings']['nested'].first.original_filename
    assert_equal 'bar.jpg', params['ie_products']['file'].original_filename
  end
  
  def test_parse_params_with_file
    input = {
      "customers[boston][first][name]" => [ "David" ],
      "something_else" => [ "blah" ],
      "logo" => [ File.new(File.dirname(__FILE__) + "/cgi_test.rb").path ]
    }
    
    expected_output = {
      "customers" => {
        "boston" => {
          "first" => {
            "name" => "David"
          }
        }
      },
      "something_else" => "blah",
      "logo" => File.new(File.dirname(__FILE__) + "/cgi_test.rb").path,
    }

    assert_equal expected_output, CGIMethods.parse_request_parameters(input)
  end

  def test_parse_params_with_array
    input = { "selected[]" =>  [ "1", "2", "3" ] }

    expected_output = { "selected" => [ "1", "2", "3" ] }

    assert_equal expected_output, CGIMethods.parse_request_parameters(input)
  end

  def test_parse_params_with_non_alphanumeric_name
    input     = { "a/b[c]" =>  %w(d) }
    expected  = { "a/b" => { "c" => "d" }}
    assert_equal expected, CGIMethods.parse_request_parameters(input)
  end

  def test_parse_params_with_single_brackets_in_middle
    input     = { "a/b[c]d" =>  %w(e) }
    expected  = { "a/b[c]d" => "e" }
    assert_equal expected, CGIMethods.parse_request_parameters(input)
  end

  def test_parse_params_with_separated_brackets
    input     = { "a/b@[c]d[e]" =>  %w(f) }
    expected  = { "a/b@" => { "c]d[e" => "f" }}
    assert_equal expected, CGIMethods.parse_request_parameters(input)
  end

  def test_parse_params_with_separated_brackets_and_array
    input     = { "a/b@[c]d[e][]" =>  %w(f) }
    expected  = { "a/b@" => { "c]d[e" => ["f"] }}
    assert_equal expected , CGIMethods.parse_request_parameters(input)
  end

  def test_parse_params_with_unmatched_brackets_and_array
    input     = { "a/b@[c][d[e][]" =>  %w(f) }
    expected  = { "a/b@" => { "c" => { "d[e" => ["f"] }}}
    assert_equal expected, CGIMethods.parse_request_parameters(input)
  end
end


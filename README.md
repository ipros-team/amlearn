# amlearn [![Build Status](https://secure.travis-ci.org/toyama0919/amlearn.png?branch=master)](http://travis-ci.org/toyama0919/amlearn)

Amazon Machine Learning opeartion very simply.

## Examples

    $ amlearn run_all -p aml-test --create_ml_model --create_batch_prediction -c config/aml.yml

## Setting

```
export AWS_ACCESS_KEY_ID=XXXXXXXXXXXXXXXXXXXXX
export AWS_SECRET_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
export AWS_DEFAULT_REGION=us-east-1
```

## Setting(aml.yml)
```
aml-test:
  bucket: machine-learning-production
  data_source_path: customer-approval/data_source.csv
  batch_prediction_data_source_path: customer-approval/predict.csv
  schema:
    attributes:
      - fieldType: CATEGORICAL
        fieldName: id
      - fieldType: TEXT
        fieldName: last_name
      - fieldType: TEXT
        fieldName: last_name_kana
      - fieldType: TEXT
        fieldName: first_name
      - fieldType: TEXT
        fieldName: first_name_kana
      - fieldType: TEXT
        fieldName: company_name
      - fieldType: TEXT
        fieldName: company_name_kana
      - fieldType: CATEGORICAL
        fieldName: trade_mark_type
      - fieldType: TEXT
        fieldName: address
      - fieldType: BINARY
        fieldName: approval_status
    dataFileContainsHeader: true
    dataFormat: CSV
    targetFieldName: approval_status
    recordAnnotationFieldName: id
    version: '1.0'
  ml_model_parameters:
    sgd.maxMLModelSizeInBytes: "2147483648"
    sgd.maxPasses: "100"
```


## Installation

Add this line to your application's Gemfile:

    gem 'amlearn'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install amlearn

## Synopsis

    $ amlearn

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new [Pull Request](../../pull/new/master)

## Information

* [Homepage](https://github.com/toyama0919/amlearn)
* [Issues](https://github.com/toyama0919/amlearn/issues)
* [Documentation](http://rubydoc.info/gems/amlearn/frames)
* [Email](mailto:toyama0919@gmail.com)

## Copyright

Copyright (c) 2016 toyama0919

See [LICENSE.txt](../LICENSE.txt) for details.

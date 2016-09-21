require 'thor'
require 'json'
require 'yaml'
require 'aws-sdk'
require 'pp'
require 'uuidtools'
require "logger"
require 'zlib'
require 'csv'

module Amlearn
  class CLI < Thor

    include Thor::Actions

    option :config, aliases: '-c', type: :string, desc: 'config'
    option :profile, aliases: '-p', type: :string, desc: 'profile'
    option :region, aliases: '-r', type: :string, default: ENV['AWS_DEFAULT_REGION'] || AWS_DEFAULT_REGION, desc: 'region'
    def initialize(args = [], options = {}, config = {})
      super(args, options, config)
      @class_options = config[:shell].base.options
      @client = Aws::MachineLearning::Client.new(region: @class_options[:region])
      @s3 = Aws::S3::Client.new(region: @class_options[:region])
      if @class_options[:config]
        @config = YAML.load(ERB.new(File.read(@class_options[:config])).result)[@class_options[:profile]]
      end
      @logger = Logger.new(STDOUT)
    end

    desc "operation_names", "operation_names"
    def operation_names
      puts JSON.pretty_generate(@client.operation_names)
    end

    desc "ml_models", "describe_ml_models"
    def ml_models
      puts_json(search(:describe_ml_models, options[:name]))
    end

    desc "batch_predictions", "batch_predictions"
    def batch_predictions
      puts_json(search(:describe_batch_predictions, options[:name]))
    end

    desc "evaluations", "evaluations"
    option :name, aliases: '-n', type: :string, desc: 'name'
    def evaluations
      puts_json(search(:describe_evaluations, options[:name]))
    end

    desc "data_sources", "data_sources"
    option :name, aliases: '-n', type: :string, desc: 'name'
    def data_sources
      puts_json(search(:describe_data_sources, options[:name]))
    end

    desc "clean", "clean"
    option :condition, type: :hash, default: {}, desc: 'example filter_variable:Status eq:FAILED'
    def clean
      params = options[:condition]
      @client.describe_batch_predictions(params).results.each do |batch_prediction|
        @logger.info(%Q{#{batch_prediction.batch_prediction_id}})
        @client.delete_batch_prediction({ batch_prediction_id: batch_prediction.batch_prediction_id })
      end
      @client.describe_evaluations(params).results.each do |evaluation|
        @client.delete_evaluation({ evaluation_id: evaluation.evaluation_id })
      end
      @client.describe_ml_models(params).results.each do |ml_model|
        @client.delete_ml_model({ ml_model_id: ml_model.ml_model_id })
      end
      search(:describe_data_sources).each do |data_source|
        @logger.info(%Q{#{data_source.data_source_id}})
        @client.delete_data_source({ data_source_id: data_source.data_source_id })
      end
    end

    desc "run_all", "run_all"
    option :name_suffix, type: :string, desc: 'batch_prediction_data_source_id'
    option :create_ml_model, type: :boolean, default: false, desc: 'create_ml_model'
    option :create_batch_prediction, type: :boolean, default: false, desc: 'create_ml_model'
    option :create_evaluation, type: :boolean, default: false, desc: 'create_evaluation'
    def run_all
      name_suffix = options[:name_suffix] || Time.now.strftime('%Y%m%d%H%M%S')

      data_source_name = 'ds_' + name_suffix
      create_data_source_from_s3_proc('data_source', data_source_name)

      batch_prediction_data_source_name = 'pds_' + name_suffix
      create_data_source_from_s3_proc('prediction_data_source', batch_prediction_data_source_name)

      if options[:create_ml_model]
        ml_model_name = 'mm_' + name_suffix
        resp = invoke(
          :create_ml_model,
          [],
          []
          .concat(['--ml_model_name', ml_model_name])
          .concat(['--data_source_name', data_source_name])
        )

        if options[:create_evaluation]
          invoke(
            :create_evaluation,
            [],
            []
            .concat(['--evaluation_name', 'e_' + name_suffix])
            .concat(['--ml_model_name', ml_model_name])
            .concat(['--evaluation_data_source_name', data_source_name])
          )
        end

        if options[:create_batch_prediction]
          invoke(
            :create_batch_prediction,
            [],
            []
            .concat(['--batch_prediction_name', 'bp_' + name_suffix])
            .concat(['--ml_model_name', ml_model_name])
            .concat(['--batch_prediction_data_source_name', batch_prediction_data_source_name])
          )
        end
      end
    end

    desc "create_data_source_from_s3", "create_data_source_from_s3"
    option :data_source_name, type: :string, desc: 'data_source_name'
    option :data_source_type, type: :string, required: true, desc: 'data_source_type', enum: ['data_source', 'prediction_data_source']
    def create_data_source_from_s3
      data_source_name = options[:data_source_name] || Time.now.strftime('%Y%m%d%H%M%S')
      create_data_source_from_s3_proc(options[:data_source_type], data_source_name)
    end

    desc "create_ml_model --data_source_name [data_source_name]", "create_ml_model"
    option :ml_model_name, type: :string, required: false, desc: 'batch_prediction_data_source_name'
    option :data_source_name, type: :string, required: true, desc: 'batch_prediction_data_source_name'
    def create_ml_model
      ml_model_name = options[:ml_model_name] || Time.now.strftime('%Y%m%d%H%M%S')
      training_data_source = search(:describe_data_sources, options[:data_source_name]).first
      option = {
        ml_model_id: SecureRandom.hex(8),
        ml_model_name: ml_model_name,
        ml_model_type: get_ml_model_type,
        parameters: @config['ml_model_parameters'],
        training_data_source_id: training_data_source.data_source_id
      }
      option[:recipe] = JSON.pretty_generate(@config['recipe']) if @config['recipe']

      resp = @client.create_ml_model(option)
      wait_from_name(ml_model_name, :describe_ml_models)
      puts resp.to_h.to_json
      resp
    end

    desc "create_evaluation", "create_evaluation"
    option :evaluation_name, type: :string, required: false, desc: 'evaluation_name'
    option :ml_model_name, type: :string, required: true, desc: 'ml_model_name'
    option :evaluation_data_source_name, type: :string, required: true, desc: 'evaluation_data_source_name'
    def create_evaluation
      evaluation_name = options[:evaluation_name] || Time.now.strftime('%Y%m%d%H%M%S')
      ml_model = search(:describe_ml_models, options[:ml_model_name]).first
      evaluation_data_source = search(:describe_data_sources, options[:evaluation_data_source_name]).first
      request = {
        evaluation_id: SecureRandom.hex(8),
        evaluation_name: evaluation_name,
        ml_model_id: ml_model.ml_model_id,
        evaluation_data_source_id: evaluation_data_source.data_source_id,
      }
      resp = @client.create_evaluation(request)
      wait_from_name(evaluation_name, :describe_evaluations)
      resp
    end

    desc "create_batch_prediction", "create_batch_prediction"
    option :batch_prediction_name, type: :string, required: false, desc: 'batch_prediction_name'
    option :ml_model_name, type: :string, required: true, desc: 'ml_model_name'
    option :batch_prediction_data_source_name, type: :string, required: true, desc: 'batch_prediction_data_source_name'
    def create_batch_prediction
      clean_results
      batch_prediction_name = options[:batch_prediction_name] || Time.now.strftime('%Y%m%d%H%M%S')
      ml_model = search(:describe_ml_models, options[:ml_model_name]).first
      batch_prediction_data_source = search(:describe_data_sources, options[:batch_prediction_data_source_name]).first

      params = {
        batch_prediction_id: SecureRandom.hex(8),
        batch_prediction_name: batch_prediction_name,
        ml_model_id: ml_model.ml_model_id,
        batch_prediction_data_source_id: batch_prediction_data_source.data_source_id,
        output_uri: "s3://#{@config['bucket']}/#{@class_options[:profile]}"
      }

      resp = @client.create_batch_prediction(params)
      wait_from_name(batch_prediction_name, :describe_batch_predictions)
      puts resp.to_h.to_json
      resp
    end

    desc "update_data_source", "update_data_source"
    option :data_source_id, aliases: '-d', type: :string, default: 'data_source.csv', desc: 'data_file_name'
    option :data_source_name, aliases: '-d', type: :string, default: 'data_source.csv', desc: 'data_file_name'
    def update_data_source
      params = {
        data_source_id: options[:data_source_id],
        data_source_name: @class_options[:profile],
      }
      resp = @client.update_data_source(params)
    end

    desc "create_realtime_endpoint", "create_realtime_endpoint"
    option :ml_model_id, type: :string, required: true, desc: 'ml_model_id'
    def create_realtime_endpoint
      resp = @client.create_realtime_endpoint({
        ml_model_id: options[:ml_model_id]
      })
      puts resp.to_h.to_json
    end

    desc "update_ml_model", "update_ml_model"
    option :ml_model_id, aliases: '-d', type: :string, required: true, desc: 'data_file_name'
    option :ml_model_name, aliases: '-d', type: :string, required: true, desc: 'data_file_name'
    def update_ml_model
      params = {
        ml_model_id: options[:ml_model_id],
        ml_model_name: options[:ml_model_name],
        score_threshold: options[:score_threshold],
      }
      @client.update_ml_model(params)
    end

    desc "prediction_results", "prediction_results"
    def prediction_results
      result_object = @s3.list_objects({
        bucket: @config['bucket'],
        prefix: "#{@class_options[:profile]}/batch-prediction/result/"
      }).contents.sort_by{ |content| content.last_modified }.last
      results = []
      @s3.get_object(bucket: @config['bucket'], key: result_object.key) do |chunk|
        buf = Zlib::GzipReader.new(StringIO.new(chunk)).read
        csv = CSV.new(buf, col_sep: ",", quote_char: "\"", headers: true)
        csv.to_a.each do |row|
          results << row.to_h
        end
      end
      puts JSON.pretty_generate(results)
    end

    private
    def puts_json(data)
      puts JSON.pretty_generate(data.map{ |struct| struct.to_h })
    end

    def get_ml_model_type
      @config['schema']['attributes'].select{ |attribute|
        attribute['fieldName'] == @config['schema']['targetFieldName'] 
      }.first['fieldType']
    end

    def clean_results
      objects = @s3.list_objects({
        bucket: @config['bucket'],
        prefix: "#{@class_options[:profile]}/batch-prediction/result/"
      })
      objects.contents.each do |content|
        resp = @s3.delete_object({
          bucket: @config['bucket'],
          key: content.key
        })
      end
    end

    def search(method_sym, name = nil)
      filter = if name
        {
          filter_variable: "Name",
          eq: name,
          sort_order: 'dsc'
        }
      else
        {}
      end

      results = []
      @client.send(method_sym, filter).each_page { |page|
        results.concat page.results
      }
      results
    end

    def wait_from_name(name, method_sym)
      @logger.info "creating #{method_sym.to_s.gsub('describe_', '')} => [#{name}]"
      loop do
        results = @client.send(method_sym, {
          filter_variable: "Name",
          eq: name
        }).results.select{ |result| DURING_STATUSES.include?(result.status) }
        return if results.size == 0
        print '.'
        sleep 20
      end
    end

    def create_data_source_from_s3_proc(data_source_type, data_source_name = Time.now.strftime('%Y%m%d%H%M%S'))
      data_location_s3 = if data_source_type == 'data_source'
        "s3://#{@config['bucket']}/#{@config['data_source_path']}"
      elsif data_source_type == 'prediction_data_source'
        "s3://#{@config['bucket']}/#{@config['batch_prediction_data_source_path']}"
      end

      request = {
        data_source_id: SecureRandom.hex(8),
        data_source_name: data_source_name,
        data_spec: {
          data_location_s3: data_location_s3,
          data_schema: JSON.pretty_generate(@config['schema'])
        },
        compute_statistics: true
      }
      @logger.info(data_location_s3)
      @client.create_data_source_from_s3(request)
      wait_from_name(data_source_name, :describe_data_sources)
    end
  end
end

# frozen_string_literal: true

class GraphqlController < ApplicationController
  PersistedQueryNotFound = Class.new(StandardError)

  def execute
    if params.key? '_json'
      result = SlingshotSchema.multiplex(
        params['_json'].map do |single|
          {
            query: single[:query],
            variables: prepare_variables(single[:variables]),
            context: { extensions: prepare_variables(single[:extensions]) },
            operation_name: single[:operationName]
          }
        end
      )

      render json: result
      return
    end

    result = FirstServiceSchema.execute(
      params[:query],
      variables: prepare_variables(params[:variables]),
      context: { extensions: prepare_variables(params[:extensions]) },
      operation_name: params[:operationName]
    )

    render json: result
  rescue => e
    raise e unless Rails.env.development?
    handle_error_in_development(e)
  end

  private

  def prepare_variables(variables_param)
    case variables_param
    when String
      if variables_param.present?
        JSON.parse(variables_param) || {}
      else
        {}
      end
    when Hash
      variables_param
    when ActionController::Parameters
      variables_param.to_unsafe_hash # GraphQL-Ruby will validate name and type of incoming variables.
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{variables_param}"
    end
  end

  def handle_error_in_development(e)
    logger.error e.message
    logger.error e.backtrace.join("\n")

    render json: { errors: [{ message: e.message, backtrace: e.backtrace }], data: {} }, status: 500
  end
end

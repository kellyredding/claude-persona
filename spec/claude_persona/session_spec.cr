require "../spec_helper"

describe ClaudePersona::Session do
  describe "PRICING_URL" do
    it "points to GitHub raw content" do
      ClaudePersona::Session::PRICING_URL.should contain("raw.githubusercontent.com")
      ClaudePersona::Session::PRICING_URL.should contain("pricing.json")
    end
  end

  describe "#parse_pricing" do
    it "parses valid pricing JSON" do
      json = <<-JSON
      {
        "version": "2026-01",
        "models": {
          "opus": {"input": 5.0, "output": 25.0, "cache_write": 6.25, "cache_read": 0.5},
          "sonnet": {"input": 3.0, "output": 15.0, "cache_write": 3.75, "cache_read": 0.3},
          "haiku": {"input": 1.0, "output": 5.0, "cache_write": 1.25, "cache_read": 0.1}
        }
      }
      JSON

      result, error = parse_pricing(json)
      error.should be_nil
      result.should_not be_nil

      if pricing = result
        pricing["opus"]["input"].should eq(5.0)
        pricing["opus"]["output"].should eq(25.0)
        pricing["sonnet"]["input"].should eq(3.0)
        pricing["haiku"]["output"].should eq(5.0)
      end
    end

    it "returns error for invalid JSON" do
      result, error = parse_pricing("not valid json")
      result.should be_nil
      error.should eq("couldn't parse pricing")
    end

    it "returns error for missing models key" do
      json = %({"version": "2026-01"})
      result, error = parse_pricing(json)
      result.should be_nil
      error.should eq("invalid pricing format")
    end

    it "returns error for missing model" do
      json = <<-JSON
      {
        "models": {
          "opus": {"input": 5.0, "output": 25.0, "cache_write": 6.25, "cache_read": 0.5},
          "sonnet": {"input": 3.0, "output": 15.0, "cache_write": 3.75, "cache_read": 0.3}
        }
      }
      JSON

      result, error = parse_pricing(json)
      result.should be_nil
      error.should eq("missing haiku pricing")
    end

    it "returns error for missing price key" do
      json = <<-JSON
      {
        "models": {
          "opus": {"input": 5.0, "output": 25.0, "cache_write": 6.25},
          "sonnet": {"input": 3.0, "output": 15.0, "cache_write": 3.75, "cache_read": 0.3},
          "haiku": {"input": 1.0, "output": 5.0, "cache_write": 1.25, "cache_read": 0.1}
        }
      }
      JSON

      result, error = parse_pricing(json)
      result.should be_nil
      error.should eq("missing opus.cache_read")
    end
  end

  describe "#calculate_cost" do
    it "calculates cost from token counts and pricing" do
      pricing = {
        "opus" => {"input" => 5.0, "output" => 25.0, "cache_write" => 6.25, "cache_read" => 0.5},
      }

      # 1000 input tokens + 500 output tokens at opus rates
      # input: (1000 / 1_000_000) * 5.0 = 0.005
      # output: (500 / 1_000_000) * 25.0 = 0.0125
      # total: 0.0175
      cost = calculate_cost(1000, 500, 0, 0, pricing["opus"])
      cost.should eq(0.0175)
    end

    it "includes cache tokens in calculation" do
      pricing = {
        "sonnet" => {"input" => 3.0, "output" => 15.0, "cache_write" => 3.75, "cache_read" => 0.3},
      }

      # 1M tokens of each type
      # input: 1.0 * 3.0 = 3.0
      # output: 1.0 * 15.0 = 15.0
      # cache_write: 1.0 * 3.75 = 3.75
      # cache_read: 1.0 * 0.3 = 0.3
      # total: 22.05
      cost = calculate_cost(1_000_000, 1_000_000, 1_000_000, 1_000_000, pricing["sonnet"])
      cost.should eq(22.05)
    end
  end

  describe "#round_cost_up" do
    it "rounds up to nearest cent" do
      round_cost_up(1.1404).should eq(1.15)
      round_cost_up(0.001).should eq(0.01)
      round_cost_up(0.999).should eq(1.0)
    end

    it "keeps exact cents unchanged" do
      round_cost_up(1.15).should eq(1.15)
      round_cost_up(0.50).should eq(0.50)
      round_cost_up(10.00).should eq(10.00)
    end

    it "handles zero" do
      round_cost_up(0.0).should eq(0.0)
    end

    it "rounds up even tiny fractions" do
      round_cost_up(0.0001).should eq(0.01)
      round_cost_up(1.0001).should eq(1.01)
    end
  end

  describe "#format_duration" do
    it "formats seconds only" do
      duration = Time::Span.new(seconds: 45)
      result = format_duration(duration)
      result.should eq("45s")
    end

    it "formats minutes and seconds" do
      duration = Time::Span.new(minutes: 5, seconds: 30)
      result = format_duration(duration)
      result.should eq("5m 30s")
    end

    it "formats hours, minutes, and seconds" do
      duration = Time::Span.new(hours: 2, minutes: 15, seconds: 45)
      result = format_duration(duration)
      result.should eq("2h 15m 45s")
    end

    it "handles zero duration" do
      duration = Time::Span.new(seconds: 0)
      result = format_duration(duration)
      result.should eq("0s")
    end
  end
end

# Extract helpers for testing
def round_cost_up(cost : Float64) : Float64
  (cost * 100).ceil / 100.0
end

def format_duration(duration : Time::Span) : String
  total_seconds = duration.total_seconds.to_i
  hours = total_seconds // 3600
  minutes = (total_seconds % 3600) // 60
  seconds = total_seconds % 60

  if hours > 0
    "#{hours}h #{minutes}m #{seconds}s"
  elsif minutes > 0
    "#{minutes}m #{seconds}s"
  else
    "#{seconds}s"
  end
end

# Parse pricing helper for testing (mirrors Session#parse_pricing)
def parse_pricing(json_str : String) : Tuple(Hash(String, Hash(String, Float64))?, String?)
  json = JSON.parse(json_str)
  models = json["models"]?
  return {nil, "invalid pricing format"} unless models

  result = {} of String => Hash(String, Float64)

  ["opus", "sonnet", "haiku"].each do |model|
    model_data = models[model]?
    return {nil, "missing #{model} pricing"} unless model_data

    prices = {} of String => Float64
    ["input", "output", "cache_write", "cache_read"].each do |key|
      value = model_data[key]?
      return {nil, "missing #{model}.#{key}"} unless value
      prices[key] = value.as_f
    end
    result[model] = prices
  end

  {result, nil}
rescue ex
  {nil, "couldn't parse pricing"}
end

# Calculate cost helper for testing
def calculate_cost(input : Int64, output : Int64, cache_write : Int64, cache_read : Int64, prices : Hash(String, Float64)) : Float64
  total = 0.0
  total += (input / 1_000_000.0) * prices["input"]
  total += (output / 1_000_000.0) * prices["output"]
  total += (cache_write / 1_000_000.0) * prices["cache_write"]
  total += (cache_read / 1_000_000.0) * prices["cache_read"]
  total
end

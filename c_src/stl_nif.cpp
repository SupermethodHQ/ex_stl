#include <fine.hpp>
#include "stl.hpp"

// Add encoders and decoders for float type
namespace fine {
  // Encoder for float
  template <> struct Encoder<float> {
    static ERL_NIF_TERM encode(ErlNifEnv *env, const float &value) {
      return enif_make_double(env, static_cast<double>(value));
    }
  };

  // Decoder for float
  template <> struct Decoder<float> {
    static float decode(ErlNifEnv *env, const ERL_NIF_TERM &term) {
      double value;
      if (!enif_get_double(env, term, &value)) {
        long int_value;
        if (enif_get_long(env, term, &int_value)) {
          value = static_cast<double>(int_value);
        } else {
          throw std::invalid_argument("Expected a number");
        }
      }
      return static_cast<float>(value);
    }
  };
}

// Helper class to represent the Params Elixir struct
namespace atoms {
  auto ElixirStlParams = fine::Atom("Elixir.Stl.Params");

  // Parameter names as atoms
  auto seasonal_length = fine::Atom("seasonal_length");
  auto trend_length = fine::Atom("trend_length");
  auto low_pass_length = fine::Atom("low_pass_length");
  auto seasonal_degree = fine::Atom("seasonal_degree");
  auto trend_degree = fine::Atom("trend_degree");
  auto low_pass_degree = fine::Atom("low_pass_degree");
  auto seasonal_jump = fine::Atom("seasonal_jump");
  auto trend_jump = fine::Atom("trend_jump");
  auto low_pass_jump = fine::Atom("low_pass_jump");
  auto inner_loops = fine::Atom("inner_loops");
  auto outer_loops = fine::Atom("outer_loops");
  auto robust = fine::Atom("robust");

  // MSTL specific params
  auto iterations = fine::Atom("iterations");
  auto lambda = fine::Atom("lambda");
  auto seasonal_lengths = fine::Atom("seasonal_lengths");
}

// Elixir struct representation for StlParams
struct ExStlParams {
  std::optional<int64_t> seasonal_length;
  std::optional<int64_t> trend_length;
  std::optional<int64_t> low_pass_length;
  std::optional<int64_t> seasonal_degree;
  std::optional<int64_t> trend_degree;
  std::optional<int64_t> low_pass_degree;
  std::optional<int64_t> seasonal_jump;
  std::optional<int64_t> trend_jump;
  std::optional<int64_t> low_pass_jump;
  std::optional<int64_t> inner_loops;
  std::optional<int64_t> outer_loops;
  std::optional<bool> robust;

  // MSTL specific fields
  std::optional<int64_t> iterations;
  std::optional<double> lambda;
  std::optional<std::vector<int64_t>> seasonal_lengths;

  static constexpr auto module = &atoms::ElixirStlParams;

  static constexpr auto fields() {
    return std::make_tuple(
      std::make_tuple(&ExStlParams::seasonal_length, &atoms::seasonal_length),
      std::make_tuple(&ExStlParams::trend_length, &atoms::trend_length),
      std::make_tuple(&ExStlParams::low_pass_length, &atoms::low_pass_length),
      std::make_tuple(&ExStlParams::seasonal_degree, &atoms::seasonal_degree),
      std::make_tuple(&ExStlParams::trend_degree, &atoms::trend_degree),
      std::make_tuple(&ExStlParams::low_pass_degree, &atoms::low_pass_degree),
      std::make_tuple(&ExStlParams::seasonal_jump, &atoms::seasonal_jump),
      std::make_tuple(&ExStlParams::trend_jump, &atoms::trend_jump),
      std::make_tuple(&ExStlParams::low_pass_jump, &atoms::low_pass_jump),
      std::make_tuple(&ExStlParams::inner_loops, &atoms::inner_loops),
      std::make_tuple(&ExStlParams::outer_loops, &atoms::outer_loops),
      std::make_tuple(&ExStlParams::robust, &atoms::robust),
      std::make_tuple(&ExStlParams::iterations, &atoms::iterations),
      std::make_tuple(&ExStlParams::lambda, &atoms::lambda),
      std::make_tuple(&ExStlParams::seasonal_lengths, &atoms::seasonal_lengths)
    );
  }
};

// Helper function to convert vectors to Elixir lists
std::vector<float> to_vector_float(ErlNifEnv* env, const ERL_NIF_TERM& term) {
  unsigned length;
  if (!enif_get_list_length(env, term, &length)) {
    throw std::invalid_argument("Expected a list");
  }

  std::vector<float> result;
  result.reserve(length);

  ERL_NIF_TERM head, tail;
  ERL_NIF_TERM list = term;

  while (enif_get_list_cell(env, list, &head, &tail)) {
    double value;
    if (!enif_get_double(env, head, &value)) {
      int int_value;
      if (enif_get_int(env, head, &int_value)) {
        value = static_cast<double>(int_value);
      } else {
        throw std::invalid_argument("List elements must be numbers");
      }
    }
    result.push_back(static_cast<float>(value));
    list = tail;
  }

  return result;
}

// Convert ExStlParams to stl::StlParams
stl::StlParams convert_params(const ExStlParams& ex_params) {
  stl::StlParams params;

  // Apply each parameter if it has a value
  #define APPLY_PARAM(name) \
    if (ex_params.name) { \
      params = params.name(*ex_params.name); \
    }

  APPLY_PARAM(seasonal_length)
  APPLY_PARAM(trend_length)
  APPLY_PARAM(low_pass_length)
  APPLY_PARAM(seasonal_degree)
  APPLY_PARAM(trend_degree)
  APPLY_PARAM(low_pass_degree)
  APPLY_PARAM(seasonal_jump)
  APPLY_PARAM(trend_jump)
  APPLY_PARAM(low_pass_jump)
  APPLY_PARAM(inner_loops)
  APPLY_PARAM(outer_loops)
  APPLY_PARAM(robust)

  #undef APPLY_PARAM

  return params;
}

// NIF to decompose with struct params
std::tuple<std::vector<float>, std::vector<float>, std::vector<float>, std::vector<float>> decompose(
  ErlNifEnv* env,
  fine::Term series_term,
  int64_t period,
  ExStlParams ex_params,
  bool include_weights
) {
  auto series = to_vector_float(env, series_term);

  if (period < 2) {
    throw std::invalid_argument("period must be greater than 1");
  }

  auto params = convert_params(ex_params);
  auto result = params.fit(series, period);

  if (include_weights) {
    return std::make_tuple(result.seasonal, result.trend, result.remainder, result.weights);
  } else {
    // Return empty weights vector if not requested
    return std::make_tuple(result.seasonal, result.trend, result.remainder, std::vector<float>());
  }
}
FINE_NIF(decompose, 0);

// NIF to decompose with multiple seasonal patterns
std::tuple<std::vector<std::vector<float>>, std::vector<float>, std::vector<float>, std::vector<float>> decompose_multi(
  ErlNifEnv* env,
  fine::Term series_term,
  std::vector<int64_t> periods_int64,
  ExStlParams ex_params
) {
  (void)env;
  auto series = to_vector_float(env, series_term);

  if (periods_int64.empty()) {
    throw std::invalid_argument("periods must not be empty");
  }

  // Convert int64_t periods to size_t
  std::vector<size_t> periods;
  periods.reserve(periods_int64.size());
  for (auto period : periods_int64) {
    if (period < 2) {
      throw std::invalid_argument("periods must be at least 2");
    }

    if (static_cast<size_t>(series.size()) < static_cast<size_t>(period * 2)) {
      throw std::invalid_argument("series has less than two periods");
    }

    periods.push_back(static_cast<size_t>(period));
  }

  // Create MSTL params and apply STL params
  auto stl_cpp_params = convert_params(ex_params);
  auto mstl_params = stl::mstl_params().stl_params(stl_cpp_params);

  // Apply MSTL specific parameters
  // Use iterations if provided
  if (ex_params.iterations) {
    mstl_params = mstl_params.iterations(static_cast<size_t>(*ex_params.iterations));
  }

  // Apply lambda if provided
  if (ex_params.lambda) {
    mstl_params = mstl_params.lambda(*ex_params.lambda);
  }

  // Apply seasonal_lengths if provided
  if (ex_params.seasonal_lengths) {
    // Convert int64_t vector to size_t vector
    std::vector<size_t> seasonal_lengths;
    seasonal_lengths.reserve(ex_params.seasonal_lengths->size());
    for (auto length : *ex_params.seasonal_lengths) {
      seasonal_lengths.push_back(static_cast<size_t>(length));
    }
    mstl_params = mstl_params.seasonal_lengths(seasonal_lengths);
  }

  // Call fit with periods
  auto result = mstl_params.fit(series, periods);

  // Return components (empty weights vector since MSTL doesn't provide weights)
  return std::make_tuple(result.seasonal, result.trend, result.remainder, std::vector<float>());
}
FINE_NIF(decompose_multi, 0);

// Helper functions for calculating strength
double seasonal_strength(ErlNifEnv* env, std::vector<float> seasonal, std::vector<float> remainder) {
  (void)env;
  return stl::StlResult<float>{seasonal, {}, remainder, {}}.seasonal_strength();
}
FINE_NIF(seasonal_strength, 0);

double trend_strength(ErlNifEnv* env, std::vector<float> trend, std::vector<float> remainder) {
  (void)env;
  return stl::StlResult<float>{{}, trend, remainder, {}}.trend_strength();
}
FINE_NIF(trend_strength, 0);

FINE_INIT("Elixir.Stl.NIF");

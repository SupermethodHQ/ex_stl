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
      std::make_tuple(&ExStlParams::robust, &atoms::robust)
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

// FINE_RESOURCE class for StlParams
class StlParamsWrapper {
public:
  StlParamsWrapper() : params_(stl::params()) {}
  stl::StlParams& params() { return params_; }
private:
  stl::StlParams params_;
};
FINE_RESOURCE(StlParamsWrapper);

// Basic parameter setter - creates a new resource
fine::ResourcePtr<StlParamsWrapper> stl_params(ErlNifEnv* env) {
  (void)env;
  return fine::make_resource<StlParamsWrapper>();
}
FINE_NIF(stl_params, 0);

// Macro to define parameter setter functions
#define DEFINE_PARAM_SETTER(name, type) \
  fine::ResourcePtr<StlParamsWrapper> set_##name(ErlNifEnv* env, fine::ResourcePtr<StlParamsWrapper> wrapper, type value) { \
    (void)env; \
    wrapper->params() = wrapper->params().name(value); \
    return wrapper; \
  } \
  FINE_NIF(set_##name, 0);

// Define all parameter setters using the macro
DEFINE_PARAM_SETTER(seasonal_length, int64_t)
DEFINE_PARAM_SETTER(trend_length, int64_t)
DEFINE_PARAM_SETTER(low_pass_length, int64_t)
DEFINE_PARAM_SETTER(seasonal_degree, int64_t)
DEFINE_PARAM_SETTER(trend_degree, int64_t)
DEFINE_PARAM_SETTER(low_pass_degree, int64_t)
DEFINE_PARAM_SETTER(seasonal_jump, int64_t)
DEFINE_PARAM_SETTER(trend_jump, int64_t)
DEFINE_PARAM_SETTER(low_pass_jump, int64_t)
DEFINE_PARAM_SETTER(inner_loops, int64_t)
DEFINE_PARAM_SETTER(outer_loops, int64_t)
DEFINE_PARAM_SETTER(robust, bool)

#undef DEFINE_PARAM_SETTER

// NIF to perform the actual decomposition using a resource
std::tuple<std::vector<float>, std::vector<float>, std::vector<float>, std::vector<float>> fit(
  ErlNifEnv* env,
  fine::ResourcePtr<StlParamsWrapper> wrapper,
  fine::Term series_term,
  int64_t period,
  bool include_weights
) {
  auto series = to_vector_float(env, series_term);

  if (period < 2) {
    throw std::invalid_argument("period must be greater than 1");
  }

  auto result = wrapper->params().fit(series, period);

  if (include_weights) {
    return std::make_tuple(result.seasonal, result.trend, result.remainder, result.weights);
  } else {
    // Return empty weights vector if not requested
    return std::make_tuple(result.seasonal, result.trend, result.remainder, std::vector<float>());
  }
}
FINE_NIF(fit, 0);

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

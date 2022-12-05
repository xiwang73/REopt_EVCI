# *********************************************************************************
# REopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
# *********************************************************************************

"""
`SteamTurbine` is an optional REopt input with the following keys and default values:
```julia
    size_class::Union{Int64, Nothing} = nothing
    min_kw::Float64 = 0.0
    max_kw::Float64 = 0.0
    electric_produced_to_thermal_consumed_ratio::Float64 = NaN
    thermal_produced_to_thermal_consumed_ratio::Float64 = NaN
    is_condensing::Bool = false
    inlet_steam_pressure_psig::Float64 = NaN
    inlet_steam_temperature_degF::Float64 = NaN
    inlet_steam_superheat_degF::Float64 = 0.0
    outlet_steam_pressure_psig::Float64 = NaN
    outlet_steam_min_vapor_fraction::Float64 = 0.8  # Minimum practical vapor fraction of steam at the exit of the steam turbine
    isentropic_efficiency::Float64 = NaN
    gearbox_generator_efficiency::Float64 = NaN  # Combined gearbox (if applicable) and electric motor/generator efficiency
    net_to_gross_electric_ratio::Float64 = NaN  # Efficiency factor to account for auxiliary loads such as pumps, controls, lights, etc
    installed_cost_per_kw::Float64 = NaN   # Installed cost based on electric power capacity
    om_cost_per_kw::Float64 = 0.0  # Fixed O&M cost based on electric power capacity
    om_cost_per_kwh::Float64 = NaN  # Variable O&M based on electric energy produced

    can_net_meter::Bool = false
    can_wholesale::Bool = false
    can_export_beyond_nem_limit::Bool = false
    can_curtail::Bool = false

    macrs_option_years::Int = 0
    macrs_bonus_fraction::Float64 = 1.0    
```

"""
Base.@kwdef mutable struct SteamTurbine <: AbstractSteamTurbine
    size_class::Union{Int64, Nothing} = nothing
    min_kw::Float64 = 0.0
    max_kw::Float64 = 0.0
    electric_produced_to_thermal_consumed_ratio::Float64 = NaN
    thermal_produced_to_thermal_consumed_ratio::Float64 = NaN
    is_condensing::Bool = false
    inlet_steam_pressure_psig::Float64 = NaN
    inlet_steam_temperature_degF::Float64 = NaN
    inlet_steam_superheat_degF::Float64 = 0.0
    outlet_steam_pressure_psig::Float64 = NaN
    outlet_steam_min_vapor_fraction::Float64 = 0.8
    isentropic_efficiency::Float64 = NaN
    gearbox_generator_efficiency::Float64 = NaN
    net_to_gross_electric_ratio::Float64 = NaN
    installed_cost_per_kw::Float64 = NaN
    om_cost_per_kw::Float64 = 0.0
    om_cost_per_kwh::Float64 = NaN
    
    can_net_meter::Bool = false
    can_wholesale::Bool = false
    can_export_beyond_nem_limit::Bool = false
    can_curtail::Bool = false

    macrs_option_years::Int = 0
    macrs_bonus_fraction::Float64 = 1.0   
end


function SteamTurbine(d::Dict; avg_boiler_fuel_load_mmbtu_per_hour::Union{Float64, Nothing}=nothing)
    st = SteamTurbine(; dictkeys_tosymbols(d)...)

    # Must provide prime_mover or all of custom_chp_inputs
    custom_st_inputs = Dict{Symbol, Any}(
        :installed_cost_per_kw => st.installed_cost_per_kw, 
        :om_cost_per_kwh => st.om_cost_per_kwh, 
        :inlet_steam_pressure_psig => st.inlet_steam_pressure_psig, 
        :inlet_steam_temperature_degF => st.inlet_steam_temperature_degF, 
        :outlet_steam_pressure_psig => st.outlet_steam_pressure_psig, 
        :isentropic_efficiency => st.isentropic_efficiency, 
        :gearbox_generator_efficiency => st.gearbox_generator_efficiency,
        :net_to_gross_electric_ratio => st.net_to_gross_electric_ratio
    )

    # set all missing default values in custom_chp_inputs
    defaults = get_steam_turbine_defaults_size_class(;avg_boiler_fuel_load_mmbtu_per_hour=avg_boiler_fuel_load_mmbtu_per_hour, 
                                            size_class=st.size_class)
    for (k, v) in custom_st_inputs
        if isnan(v)
            if !(k == :inlet_steam_temperature_degF && !isnan(st.inlet_steam_superheat_degF))
                setproperty!(st, k, defaults[string(k)])
            else
                @warn("Steam turbine inlet temperature will be calculated from inlet pressure and specified superheat")
            end
        end
    end

    if isnan(st.electric_produced_to_thermal_consumed_ratio) || isnan(thermal_produced_to_thermal_consumed_ratio)
        assign_st_elec_and_therm_prod_ratios!(st)
    end

    return st
end


"""
    get_steam_turbine_defaults(size_class::Int, defaults::Dict)

return a Dict{String, Float64} by selecting the appropriate values from 
data/steam_turbine/steam_turbine_default_data.json, which contains values based on size_class for the 
custom_st_inputs, i.e.
- `installed_cost_per_kw`
- `om_cost_per_kwh`
- `inlet_steam_pressure_psig`
- `inlet_steam_temperature_degF`
- `outlet_steam_pressure_psig`
- `isentropic_efficiency`
- `gearbox_generator_efficiency`
- `net_to_gross_electric_ratio`
"""
function get_steam_turbine_defaults(size_class::Int, defaults_all::Dict)
    steam_turbine_defaults = Dict{String, Any}()

    for key in keys(defaults_all)
        steam_turbine_defaults[key] = defaults_all[key][size_class]
    end
    defaults_all = nothing

    return steam_turbine_defaults
end

"""
    assign_st_elec_and_therm_prod_ratios!(st::SteamTurbine) 

Calculate steam turbine (ST) electric output to thermal input ratio based on inlet and outlet steam conditions and ST performance.
This function uses the CoolProp package to calculate steam properties, and does standard thermodynamics textbook isentropic efficiency calculations.
    Units of [kWe_net / kWt_in]
:return: st_elec_out_to_therm_in_ratio, st_therm_out_to_therm_in_ratio

"""
function assign_st_elec_and_therm_prod_ratios!(st::SteamTurbine)
    # Convert input steam conditions to SI (absolute pressures, not gauge)
    # Steam turbine inlet steam conditions and calculated properties
    p_in_pa = (st.inlet_steam_pressure_psig / 14.5038 + 1.01325) * 1.0E5
    if isnan(st.inlet_steam_temperature_degF)
        t_in_sat_k = PropsSI("T","P",p_in_pa,"Q",1.0,"Water")
        t_superheat_in_k = (st.inlet_steam_superheat_degF - 32.0) * 5.0 / 9.0 + 273.15
        t_in_k = t_in_sat_k + t_superheat_in_k
    else
        t_in_k = (st.inlet_steam_temperature_degF - 32.0) * 5.0 / 9.0 + 273.15
    end
    h_in_j_per_kg = PropsSI("H","P",p_in_pa,"T",t_in_k,"Water")
    s_in_j_per_kgK = PropsSI("S","P",p_in_pa,"T",t_in_k,"Water")

    # Steam turbine outlet steam conditions and calculated properties
    p_out_pa = (st.outlet_steam_pressure_psig / 14.5038 + 1.01325) * 1.0E5
    h_out_ideal_j_per_kg = PropsSI("H","P",p_out_pa,"S",s_in_j_per_kgK,"Water")
    h_out_j_per_kg = h_in_j_per_kg - st.isentropic_efficiency * (h_in_j_per_kg - h_out_ideal_j_per_kg)
    x_out = PropsSI("Q","P",p_out_pa,"H",h_out_j_per_kg,"Water")

    # Check if the outlet steam vapor fraction is lower than the lowest allowable (-1 means superheated so no problem)
    if x_out != -1.0 && x_out < st.outlet_steam_min_vapor_fraction
        throw(@error("The calculated steam outlet vapor fraction of $x_out is lower than the minimum allowable value of $(st.outlet_steam_min_vapor_fraction)"))
    end

    # Steam turbine shaft power calculations from enthalpy difference at inlet and outlet, and net power with efficiencies
    st_shaft_power_kwh_per_kg = (h_in_j_per_kg - h_out_j_per_kg) / 1000.0 / 3600.0
    st_net_elec_power_kwh_per_kg = st_shaft_power_kwh_per_kg * st.gearbox_generator_efficiency * st.net_to_gross_electric_ratio

    # Condenser heat rejection or heat recovery if steam turbine is back-pressure (is_condensing = false)
    if st.is_condensing
        heat_recovered_kwh_per_kg = 0.0
    else
        h_out_sat_liq_j_per_kg = PropsSI("H","P",p_out_pa,"Q",0.0,"Water")
        heat_recovered_kwh_per_kg = (h_out_j_per_kg - h_out_sat_liq_j_per_kg) / 1000.0 / 3600.0
    end

    # Boiler thermal Power - assume enthalpy at saturated liquid condition (ignore delta H of pump)
    h_boiler_in_j_per_kg = PropsSI("H","P",p_out_pa,"Q",0.0,"Water")
    boiler_therm_power_kwh_per_kg = (h_in_j_per_kg - h_boiler_in_j_per_kg) / 1000.0 / 3600.0

    # Calculate output ratios to be used in the REopt optimization model
    if isnan(st.electric_produced_to_thermal_consumed_ratio)
        st.electric_produced_to_thermal_consumed_ratio = st_net_elec_power_kwh_per_kg / boiler_therm_power_kwh_per_kg
    end

    if isnan(st.thermal_produced_to_thermal_consumed_ratio)
        st.thermal_produced_to_thermal_consumed_ratio = heat_recovered_kwh_per_kg / boiler_therm_power_kwh_per_kg
    end

    nothing
end

"""
    get_steam_turbine_defaults_size_class(;avg_boiler_fuel_load_mmbtu_per_hour::Union{Float64, Nothing}=nothing,
                                    size_class::Union{Int64, Nothing}=nothing)

Depending on the set of inputs, different sets of outputs are determine in addition to all SteamTurbine cost and performance parameter defaults:
    1. Inputs: avg_boiler_fuel_load_mmbtu_per_hour
       Outputs: size_class, st_size_based_on_avg_heating_load_kw
    2. Inputs: sized_class
       Outputs: (gets defaults directly from size_class)
"""
function get_steam_turbine_defaults_size_class(;avg_boiler_fuel_load_mmbtu_per_hour::Union{Float64, Nothing}=nothing, size_class::Union{Int64, Nothing}=nothing)
    defaults = JSON.parsefile(joinpath(dirname(@__FILE__), "..", "..", "data", "steam_turbine", "steam_turbine_default_data.json"))
    class_bounds = [(0.0, 25000.0), (0, 1000.0), (1000.0, 5000.0), (5000.0, 25000.0)]
    n_classes = length(class_bounds)
    if !isnothing(size_class)
        if size_class < 1 || size_class > n_classes
            throw(@error "Invalid size_class given for steam_turbine, must be in [1,2,3,4]")
        end
    end
    if !isnothing(avg_boiler_fuel_load_mmbtu_per_hour)
        if avg_boiler_fuel_load_mmbtu_per_hour <= 0
            throw(@error "avg_boiler_fuel_load_mmbtu_per_hour must be > 0.0 MMBtu/hr")
        end
        steam_turbine_electric_efficiency = 0.07 # Typical, steam_turbine_kwe / boiler_fuel_kwt
        thermal_power_in_kw = avg_boiler_fuel_load_mmbtu_per_hour * KWH_PER_MMBTU
        st_elec_size_heuristic_kw = thermal_power_in_kw * steam_turbine_electric_efficiency
        # With heuristic size, find the suggested size class
        if st_elec_size_heuristic_kw < class_bounds[2][2]
            # If smaller than the upper bound of the smallest class, assign the smallest class
            size_class = 2
        elseif st_elec_size_heuristic_kw >= class_bounds[n_classes][1]
            # If larger than or equal to the lower bound of the largest class, assign the largest class
            size_class = n_classes  # Size classes are zero-indexed
        else
            # For middle size classes
            for sc in 2:(n_classes-1)
                if st_elec_size_heuristic_kw >= class_bounds[sc][1] &&
                    st_elec_size_heuristic_kw < class_bounds[sc][2]
                    size_class = sc
                end
            end
        end
    else
        size_class = 1
        st_elec_size_heuristic_kw = nothing
    end

    steam_turbine_defaults = get_steam_turbine_defaults(size_class, defaults)
    
    response = Dict([
        ("prime_mover", "steam_turbine"),
        ("size_class", size_class),
        ("default_inputs", steam_turbine_defaults),
        ("chp_size_based_on_avg_heating_load_kw", st_elec_size_heuristic_kw),
        ("size_class_bounds", class_bounds)
    ])

    return response

end
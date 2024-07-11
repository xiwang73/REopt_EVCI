# ASDL

# Base.@kwdef mutable struct Degradation
#     calendar_fade_coefficient::Real = 2.46E-03
#     cycle_fade_coefficient::Real = 7.82E-05
#     time_exponent::Real = 0.5
#     installed_cost_per_kwh_declination_rate::Real = 0.05
#     maintenance_strategy::String = "augmentation"  # one of ["augmentation", "replacement"]
#     maintenance_cost_per_kwh::Vector{<:Real} = Real[]
# end


Base.@kwdef struct ChargingStationDefaults
    off_grid_flag::Bool = false
    min_kw::Real = 0.0
    max_kw::Real = 1.0e4
    min_kwh::Real = 0.0
    max_kwh::Real = 1.0e6
    internal_efficiency_fraction::Float64 = 0.975
    inverter_efficiency_fraction::Float64 = 0.96
    rectifier_efficiency_fraction::Float64 = 0.96
    soc_min_fraction::Float64 = 0.2
    soc_min_applies_during_outages::Bool = false
    soc_init_fraction::Float64 = off_grid_flag ? 1.0 : 0.5
    can_grid_charge::Bool = off_grid_flag ? false : true
    installed_cost_per_kw::Real = 910.0
    installed_cost_per_kwh::Real = 455.0
    replace_cost_per_kw::Real = 715.0
    replace_cost_per_kwh::Real = 318.0
    inverter_replacement_year::Int = 10
    battery_replacement_year::Int = 10
    macrs_option_years::Int = 7
    macrs_bonus_fraction::Float64 = 0.6
    macrs_itc_reduction::Float64 = 0.5
    total_itc_fraction::Float64 = 0.3
    total_rebate_per_kw::Real = 0.0
    total_rebate_per_kwh::Real = 0.0
    charge_efficiency::Float64 = rectifier_efficiency_fraction * internal_efficiency_fraction^0.5
    discharge_efficiency::Float64 = inverter_efficiency_fraction * internal_efficiency_fraction^0.5
    grid_charge_efficiency::Float64 = can_grid_charge ? charge_efficiency : 0.0
    model_degradation::Bool = false
    degradation::Dict = Dict()
    minimum_avg_soc_fraction::Float64 = 0.0
end


"""
    function ElectricStorage(d::Dict, f::Financial, settings::Settings)

Construct ElectricStorage struct from Dict with keys-val pairs from the 
REopt ElectricStorage and Financial inputs.
"""
struct ChargingStation <: AbstractElectricStorage
    min_kw::Real
    max_kw::Real
    min_kwh::Real
    max_kwh::Real
    internal_efficiency_fraction::Float64
    inverter_efficiency_fraction::Float64
    rectifier_efficiency_fraction::Float64
    soc_min_fraction::Float64
    soc_min_applies_during_outages::Bool
    soc_init_fraction::Float64
    can_grid_charge::Bool
    installed_cost_per_kw::Real
    installed_cost_per_kwh::Real
    replace_cost_per_kw::Real
    replace_cost_per_kwh::Real
    inverter_replacement_year::Int
    battery_replacement_year::Int
    macrs_option_years::Int
    macrs_bonus_fraction::Float64
    macrs_itc_reduction::Float64
    total_itc_fraction::Float64
    total_rebate_per_kw::Real
    total_rebate_per_kwh::Real
    charge_efficiency::Float64
    discharge_efficiency::Float64
    grid_charge_efficiency::Float64
    net_present_cost_per_kw::Real
    net_present_cost_per_kwh::Real
    model_degradation::Bool
    degradation::Degradation
    minimum_avg_soc_fraction::Float64

    function ChargingStation(d::Dict, f::Financial)  
        s = ChargingStationDefaults(;d...)

        if s.inverter_replacement_year >= f.analysis_years
            @warn "Battery inverter replacement costs (per_kw) will not be considered because inverter_replacement_year is greater than or equal to analysis_years."
        end

        if s.battery_replacement_year >= f.analysis_years
            @warn "Battery replacement costs (per_kwh) will not be considered because battery_replacement_year is greater than or equal to analysis_years."
        end

        net_present_cost_per_kw = effective_cost(;
            itc_basis = s.installed_cost_per_kw,
            replacement_cost = s.inverter_replacement_year >= f.analysis_years ? 0.0 : s.replace_cost_per_kw,
            replacement_year = s.inverter_replacement_year,
            discount_rate = f.owner_discount_rate_fraction,
            tax_rate = f.owner_tax_rate_fraction,
            itc = s.total_itc_fraction,
            macrs_schedule = s.macrs_option_years == 7 ? f.macrs_seven_year : f.macrs_five_year,
            macrs_bonus_fraction = s.macrs_bonus_fraction,
            macrs_itc_reduction = s.macrs_itc_reduction,
            rebate_per_kw = s.total_rebate_per_kw
        )
        net_present_cost_per_kwh = effective_cost(;
            itc_basis = s.installed_cost_per_kwh,
            replacement_cost = s.battery_replacement_year >= f.analysis_years ? 0.0 : s.replace_cost_per_kwh,
            replacement_year = s.battery_replacement_year,
            discount_rate = f.owner_discount_rate_fraction,
            tax_rate = f.owner_tax_rate_fraction,
            itc = s.total_itc_fraction,
            macrs_schedule = s.macrs_option_years == 7 ? f.macrs_seven_year : f.macrs_five_year,
            macrs_bonus_fraction = s.macrs_bonus_fraction,
            macrs_itc_reduction = s.macrs_itc_reduction
        )

        net_present_cost_per_kwh -= s.total_rebate_per_kwh

        if haskey(d, :degradation)
            degr = Degradation(;dictkeys_tosymbols(d[:degradation])...)
        else
            degr = Degradation()
        end

        # copy the replace_costs in case we need to change them
        replace_cost_per_kw = s.replace_cost_per_kw 
        replace_cost_per_kwh = s.replace_cost_per_kwh
        if s.model_degradation
            if haskey(d, :replace_cost_per_kw) && d[:replace_cost_per_kw] != 0.0 || 
                haskey(d, :replace_cost_per_kwh) && d[:replace_cost_per_kwh] != 0.0
                @warn "Setting ElectricStorage replacement costs to zero. Using degradation.maintenance_cost_per_kwh instead."
            end
            replace_cost_per_kw = 0.0
            replace_cost_per_kwh = 0.0
        end
    
        return new(
            s.min_kw,
            s.max_kw,
            s.min_kwh,
            s.max_kwh,
            s.internal_efficiency_fraction,
            s.inverter_efficiency_fraction,
            s.rectifier_efficiency_fraction,
            s.soc_min_fraction,
            s.soc_min_applies_during_outages,
            s.soc_init_fraction,
            s.can_grid_charge,
            s.installed_cost_per_kw,
            s.installed_cost_per_kwh,
            replace_cost_per_kw,
            replace_cost_per_kwh,
            s.inverter_replacement_year,
            s.battery_replacement_year,
            s.macrs_option_years,
            s.macrs_bonus_fraction,
            s.macrs_itc_reduction,
            s.total_itc_fraction,
            s.total_rebate_per_kw,
            s.total_rebate_per_kwh,
            s.charge_efficiency,
            s.discharge_efficiency,
            s.grid_charge_efficiency,
            net_present_cost_per_kw,
            net_present_cost_per_kwh,
            s.model_degradation,
            degr,
            s.minimum_avg_soc_fraction
        )
    end
end

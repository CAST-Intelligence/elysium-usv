#!/usr/bin/env python3
"""
Compare full payload calculation (all 5 payloads) vs Excel calculation (first 4 payloads)
"""

def main():
    # Define payload values from H33 yellow Excel sheet
    payloads = [
        {"name": "RS-232 sensors", "power": 3.5, "duty_cycle": 1.0},  # 100%
        {"name": "Nortek", "power": 20, "duty_cycle": 0.1},  # 10%
        {"name": "Ekinox IMU", "power": 3.5, "duty_cycle": 1.0},  # 100%
        {"name": "Starlink", "power": 100, "duty_cycle": 0.05},  # 5%
        {"name": "Eddie", "power": 10, "duty_cycle": 0.5}  # 50%
    ]
    
    # Excel reported value
    excel_reported_value = 14.0  # Watts
    
    # Calculate payload power with all 5 payloads
    full_payload_power = 0
    for payload in payloads:
        full_payload_power += payload["power"] * payload["duty_cycle"]
    
    # Calculate payload power with just first 4 payloads (Excel formula)
    excel_calculated_power = 0
    for payload in payloads[:4]:
        excel_calculated_power += payload["power"] * payload["duty_cycle"]
    
    # Print comparison table
    print("Payload Power Calculation Comparison")
    print("=====================================")
    print("\nIndividual payload contributions:")
    
    for i, payload in enumerate(payloads):
        power = payload["power"] * payload["duty_cycle"]
        included = "INCLUDED in Excel" if i < 4 else "NOT included in Excel"
        print(f"{i+1}. {payload['name']}: {payload['power']}W * {payload['duty_cycle']*100:.1f}% = {power:.1f}W ({included})")
    
    print("\nTotal power calculations:")
    print(f"Excel reported value: {excel_reported_value}W")
    print(f"Calculated with first 4 payloads: {excel_calculated_power:.1f}W")
    print(f"Calculated with all 5 payloads: {full_payload_power:.1f}W")
    
    print("\nDifference analysis:")
    print(f"Difference between Excel and 4-payload calc: {excel_reported_value - excel_calculated_power:.1f}W")
    print(f"Difference between full (5) and partial (4) calc: {full_payload_power - excel_calculated_power:.1f}W")
    print(f"Fifth payload (Eddie) contribution: {payloads[4]['power'] * payloads[4]['duty_cycle']:.1f}W")
    
    # Derive the formula used in Excel
    excel_formula = "=(1-0%)*SUM("
    for i, payload in enumerate(payloads[:4]):
        if i > 0:
            excel_formula += ","
        excel_formula += f"{payload['power']}*{payload['duty_cycle']*100:.1f}%"
    excel_formula += f") = {excel_calculated_power:.1f}W"
    
    print(f"\nExcel formula: {excel_formula}")
    
    # Show impact on mission endurance calculation
    print("\nIMPACT ON MISSION CALCULATION:")
    
    # Constants from Excel
    battery_capacity_wh = 4000  # Wh
    solar_nominal_w = 420  # W
    solar_derating = 0.7  # 70%
    daily_ghi = 5.2  # kWh/m²/day
    generator_full_tank_wh = 11000  # Wh
    generator_efficiency = 0.7  # 70%
    starting_soc = 0.96  # 96%
    mission_cancel_soc = 0.15  # 15%
    generator_starting_fill = 1.0  # 100%
    average_speed = 1.25  # knots
    station_keep_percent = 0.0  # 0%
    house_load_performance = 25  # W
    
    # Function for calculating propulsion power
    def calculate_power_for_speed(speed_in_knots):
        a = 4.5485
        b = -27.872
        c = 55.55
        d = -13.27885
        e = 0
        power = a * speed_in_knots**4 + b * speed_in_knots**3 + c * speed_in_knots**2 + d * speed_in_knots + e
        return max(0, power)
    
    # Calculate with Excel method (4 payloads)
    daily_solar_input = solar_nominal_w * daily_ghi * solar_derating
    avg_solar_input = daily_solar_input / 24
    propulsion_power = (1 - station_keep_percent) * calculate_power_for_speed(average_speed)
    house_power = house_load_performance
    
    total_power_excel = excel_calculated_power + propulsion_power + house_power
    net_power_excel = avg_solar_input - total_power_excel
    
    available_battery_energy = (starting_soc - mission_cancel_soc) * battery_capacity_wh
    available_generator_energy = generator_starting_fill * generator_full_tank_wh * generator_efficiency
    total_available_energy = available_battery_energy + available_generator_energy
    
    endurance_hours_excel = total_available_energy / abs(net_power_excel) if net_power_excel < 0 else float('inf')
    endurance_days_excel = endurance_hours_excel / 24
    
    # Calculate with full 5 payloads
    total_power_full = full_payload_power + propulsion_power + house_power
    net_power_full = avg_solar_input - total_power_full
    
    endurance_hours_full = total_available_energy / abs(net_power_full) if net_power_full < 0 else float('inf')
    endurance_days_full = endurance_hours_full / 24
    
    print(f"Daily solar input: {daily_solar_input:.1f}Wh")
    print(f"Avg solar input: {avg_solar_input:.1f}W")
    print(f"Propulsion power: {propulsion_power:.1f}W")
    print(f"House power: {house_power:.1f}W")
    
    print("\nWith Excel method (4 payloads):")
    print(f"  Payload power: {excel_calculated_power:.1f}W")
    print(f"  Total power consumption: {total_power_excel:.1f}W")
    print(f"  Net power balance: {net_power_excel:.1f}W")
    endurance_str = f"{endurance_days_excel:.1f} days" if endurance_days_excel != float('inf') else "Infinite"
    print(f"  Mission endurance: {endurance_str}")
    
    print("\nWith all 5 payloads:")
    print(f"  Payload power: {full_payload_power:.1f}W")
    print(f"  Total power consumption: {total_power_full:.1f}W")
    print(f"  Net power balance: {net_power_full:.1f}W")
    endurance_str = f"{endurance_days_full:.1f} days" if endurance_days_full != float('inf') else "Infinite"
    print(f"  Mission endurance: {endurance_str}")
    
    print("\nConclusion:")
    print(f"  Difference in endurance: {abs(endurance_days_excel - endurance_days_full):.1f} days")
    percent_diff = abs(endurance_days_excel - endurance_days_full) / endurance_days_excel * 100 if endurance_days_excel != float('inf') else float('inf')
    print(f"  Percent difference: {percent_diff:.1f}%")
    print("  The Excel calculation (using only 4 payloads) significantly overestimates mission endurance")
    print("  compared to using all 5 payloads, because it underestimates power consumption.")

if __name__ == "__main__":
    main()
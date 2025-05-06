#!/usr/bin/env python3
"""
Analyze the discrepancies between the Excel Power Planner and Python implementation.
"""
import numpy as np

# Define the speed-power curve function
def calculate_power_for_speed(speed_in_knots):
    """
    Calculate power required in Watts for given speed in knots.
    Uses a 4th-order polynomial fit based on the reference data.
    """
    # Polynomial coefficients from the Excel formula
    a = 4.5485
    b = -27.872
    c = 55.55
    d = -13.27885
    e = 0  # No constant term in the formula
    
    # Calculate power using the polynomial fit
    power = a * speed_in_knots**4 + b * speed_in_knots**3 + c * speed_in_knots**2 + d * speed_in_knots + e
    
    # Ensure power is not negative
    return max(0, power)

class PowerPlanner:
    def __init__(self):
        # Initialize with default values similar to the Excel template
        # Standard fixed constants
        self.battery_capacity_wh = 4000  # Wh
        self.solar_nominal_w = 420  # W
        self.solar_derating = 0.7  # 70%
        self.generator_full_tank_wh = 11000  # Wh
        self.generator_efficiency = 0.7  # 70%
        
        # Default operational parameters
        self.starting_soc = 0.96  # 96%
        self.mission_cancel_soc = 0.15  # 15%
        self.generator_use = True
        self.generator_starting_fill = 1.0  # 100%
        self.average_speed = 1.25  # knots
        self.station_keep_percent = 0.0  # 0%
        self.daily_ghi = 5.2  # kWh/m²/day
        self.power_save_mode_percent = 0.0  # 0%
        
        # House loads
        self.house_load_performance = 25  # W
        self.house_load_power_save = 20  # W
        
        # Payloads with default values
        self.payloads = [
            {"name": "RS-232 sensors", "power": 3.5, "duty_cycle": 1.0},  # 100%
            {"name": "Nortek", "power": 20, "duty_cycle": 0.1},  # 10%
            {"name": "Ekinox IMU", "power": 3.5, "duty_cycle": 1.0},  # 100%
            {"name": "Starlink", "power": 100, "duty_cycle": 0.05},  # 5%
            {"name": "Eddie", "power": 10, "duty_cycle": 0.5}  # 50%
        ]
    
    def calculate_daily_solar_input(self):
        """Calculate daily solar input in Wh"""
        return self.solar_nominal_w * self.daily_ghi * self.solar_derating
    
    def calculate_average_solar_input(self):
        """Calculate 24-hour average solar input in W"""
        return self.calculate_daily_solar_input() / 24
    
    def calculate_payload_power(self):
        """Calculate average hourly payload power consumption in W"""
        total_power = 0
        # Match Excel behavior by only including the first 4 payloads
        for i, payload in enumerate(self.payloads[:4]):  # Only first 4 payloads to match Excel
            total_power += payload["power"] * payload["duty_cycle"]
        return (1 - self.power_save_mode_percent) * total_power
    
    def calculate_propulsion_power(self):
        """Calculate average propulsion power in W"""
        # Only consuming propulsion power when not station keeping
        return (1 - self.station_keep_percent) * calculate_power_for_speed(self.average_speed)
    
    def calculate_house_power(self):
        """Calculate average house power consumption in W"""
        return self.power_save_mode_percent * self.house_load_power_save + \
               (1 - self.power_save_mode_percent) * self.house_load_performance
    
    def calculate_total_power_draw(self):
        """Calculate total power consumption in W"""
        return self.calculate_payload_power() + \
               self.calculate_propulsion_power() + \
               self.calculate_house_power()
    
    def calculate_net_power_draw(self):
        """Calculate net power balance in W (negative means consumption exceeds generation)"""
        return self.calculate_average_solar_input() - self.calculate_total_power_draw()
    
    def calculate_mission_endurance(self):
        """Calculate mission endurance in days"""
        net_power = self.calculate_net_power_draw()
        
        # If net power is positive or zero, the mission can continue indefinitely
        if net_power >= 0:
            return float('inf')
        
        # Calculate available energy from battery and generator
        available_battery_energy = (self.starting_soc - self.mission_cancel_soc) * self.battery_capacity_wh
        available_generator_energy = 0
        if self.generator_use:
            available_generator_energy = self.generator_starting_fill * \
                                         self.generator_full_tank_wh * \
                                         self.generator_efficiency
        
        total_available_energy = available_battery_energy + available_generator_energy
        
        # Calculate endurance in days
        endurance_hours = total_available_energy / abs(net_power)
        endurance_days = endurance_hours / 24
        
        return endurance_days
    
    def calculate_mission_range(self):
        """Calculate mission range in nautical miles"""
        endurance_days = self.calculate_mission_endurance()
        if endurance_days == float('inf'):
            return float('inf')
        
        daily_distance = (1 - self.station_keep_percent) * self.average_speed * 24
        return daily_distance * endurance_days
    
    def calculate_daily_range(self):
        """Calculate range in 24 hours in nautical miles"""
        return (1 - self.station_keep_percent) * self.average_speed * 24
    
    def calculate_weekly_range(self):
        """Calculate range in 7 days in nautical miles"""
        endurance_days = self.calculate_mission_endurance()
        if endurance_days >= 7:
            return 7 * self.calculate_daily_range()
        else:
            return endurance_days * self.calculate_daily_range()
    
    def get_summary(self):
        """Get a summary of all calculated values"""
        # Calculate all values
        daily_solar_input = self.calculate_daily_solar_input()
        average_solar_input = self.calculate_average_solar_input()
        payload_power = self.calculate_payload_power()
        propulsion_power = self.calculate_propulsion_power()
        house_power = self.calculate_house_power()
        total_power_draw = self.calculate_total_power_draw()
        net_power_draw = self.calculate_net_power_draw()
        mission_endurance = self.calculate_mission_endurance()
        mission_range = self.calculate_mission_range()
        daily_range = self.calculate_daily_range()
        weekly_range = self.calculate_weekly_range()
        
        # Format infinity for display
        if mission_endurance == float('inf'):
            mission_endurance_str = "Infinite"
        else:
            mission_endurance_str = f"{mission_endurance:.1f}"
            
        if mission_range == float('inf'):
            mission_range_str = "Infinite"
        else:
            mission_range_str = f"{mission_range:.1f}"
        
        # Create summary dictionary
        summary = {
            "Daily solar input (Wh)": daily_solar_input,
            "24-hour average solar input (W)": average_solar_input,
            "Average payload power (W)": payload_power,
            "Average propulsion power (W)": propulsion_power,
            "Average house power (W)": house_power,
            "Total power consumption (W)": total_power_draw,
            "Net power balance (W)": net_power_draw,
            "Mission endurance (days)": mission_endurance_str,
            "Mission range (nautical miles)": mission_range_str,
            "Daily range (nautical miles)": daily_range,
            "Weekly range (nautical miles)": weekly_range
        }
        
        return summary

def main():
    # Create and configure an H33 planner instance with exact values from Excel
    h33_planner = PowerPlanner()

    # Set values from "Power Planner - H33 yellow" Excel sheet
    h33_planner.starting_soc = 0.96  # 96%
    h33_planner.mission_cancel_soc = 0.15  # 15%
    h33_planner.generator_use = True
    h33_planner.generator_starting_fill = 1.0  # 100%
    h33_planner.average_speed = 1.25
    h33_planner.station_keep_percent = 0.0  # 0%
    h33_planner.daily_ghi = 5.2
    h33_planner.power_save_mode_percent = 0.0  # 0%
    h33_planner.house_load_performance = 25

    # Set payload values
    h33_planner.payloads = [
        {"name": "RS-232 sensors", "power": 3.5, "duty_cycle": 1.0},  # 100%
        {"name": "Nortek", "power": 20, "duty_cycle": 0.1},  # 10%
        {"name": "Ekinox IMU", "power": 3.5, "duty_cycle": 1.0},  # 100%
        {"name": "Starlink", "power": 100, "duty_cycle": 0.05},  # 5%
        {"name": "Eddie", "power": 10, "duty_cycle": 0.5}  # 50%
    ]

    # Excel H33 values from "Power Planner - H33 yellow" sheet
    excel_h33_values = {
        "Daily solar input (Wh)": 1529,
        "24-hour average solar input (W)": 63.7,
        "Average payload power (W)": 14,
        "Average propulsion power (W)": 26.9,
        "Average house power (W)": 25,
        "Total power consumption (W)": 65.9,
        "Net power balance (W)": -2.2,
        "Mission endurance (days)": 210.5,
        "Mission range (nautical miles)": 6314.8,
        "Daily range (nautical miles)": 30,
        "Weekly range (nautical miles)": 210.0
    }

    # Get calculated values
    python_values = h33_planner.get_summary()

    print("Comparing H33 Power Planner Excel values to Python calculation")
    print("==============================================================\n")

    # Create a comparison table
    print("| Metric | Excel Value | Python Value | Difference | % Difference |")
    print("|--------|------------|--------------|------------|--------------|")

    for key, excel_val in excel_h33_values.items():
        python_val = python_values[key]
        
        # Convert string values if needed
        if isinstance(python_val, str):
            if python_val == "Infinite":
                python_val = float('inf')
            else:
                python_val = float(python_val)
        
        # Calculate difference
        if isinstance(excel_val, (int, float)) and isinstance(python_val, (int, float)):
            abs_diff = python_val - excel_val
            
            # Calculate percentage difference (avoid division by zero)
            if excel_val != 0:
                pct_diff = (abs_diff / excel_val) * 100
            else:
                pct_diff = float('inf') if abs_diff != 0 else 0
                
            print(f"| {key} | {excel_val} | {python_val:.1f} | {abs_diff:.1f} | {pct_diff:.1f}% |")
        else:
            print(f"| {key} | {excel_val} | {python_val} | N/A | N/A |")

    print("\n## Analysis of Discrepancies")
    print("""
1. **Speed-Power Relationship**: The polynomial formula for calculating power from speed may have slight coefficient differences.
   - Excel formula: `=4.5485*D31^4-27.872*D31^3+55.55*D31^2-13.27885*D31`
   - Python formula: `a * speed_in_knots**4 + b * speed_in_knots**3 + c * speed_in_knots**2 + d * speed_in_knots + e`

2. **Rounding Errors**: Excel might round intermediate calculations differently than Python.

3. **Payload Power Calculation**: Small differences in how duty cycles are applied.

4. **Endurance Calculation**: Differences in how available energy and power consumption are calculated.

5. **Solar Power Calculation**: Slight variations in how solar power is calculated under different GHI values.
    """)

    print("## Detailed Calculation Breakdown")
    print(f"Solar nominal: {h33_planner.solar_nominal_w}W")
    print(f"Solar derating: {h33_planner.solar_derating}")
    print(f"Daily GHI: {h33_planner.daily_ghi} kWh/m²/day")
    print(f"Calculated daily solar input: {h33_planner.calculate_daily_solar_input():.1f}Wh")
    print(f"Excel daily solar input: {excel_h33_values['Daily solar input (Wh)']}Wh")
    print(f"Formula check: {h33_planner.solar_nominal_w} * {h33_planner.daily_ghi} * {h33_planner.solar_derating} = {h33_planner.solar_nominal_w * h33_planner.daily_ghi * h33_planner.solar_derating:.1f}Wh")

    print("\nPower at speed calculation:")
    print(f"Speed: {h33_planner.average_speed} knots")
    print(f"Python power calculation: {calculate_power_for_speed(h33_planner.average_speed):.1f}W")
    print(f"Excel power value: {excel_h33_values['Average propulsion power (W)']}W")

    print("\nPayload power breakdown:")
    print(f"Excel payload power: {excel_h33_values['Average payload power (W)']}W")
    
    # Excel formula only includes the first 4 payloads! It doesn't include "Eddie"
    excel_payload_calc = 0
    for i, payload in enumerate(h33_planner.payloads):
        power = payload["power"] * payload["duty_cycle"]
        included = "INCLUDED" if i < 4 else "NOT INCLUDED in Excel!"
        print(f"- {payload['name']}: {payload['power']}W * {payload['duty_cycle']*100}% = {power:.1f}W ({included})")
        if i < 4:  # Only the first 4 payloads (exclude Eddie which is at index 4)
            excel_payload_calc += power
    
    total_payload = sum(payload["power"] * payload["duty_cycle"] for payload in h33_planner.payloads)
    print(f"Total calculated payload power (all 5 payloads): {total_payload:.1f}W")
    print(f"Payload power with just first 4 payloads: {excel_payload_calc:.1f}W")
    print(f"Excel formula: =(1-0%)*SUM(3.5*100%,20*10%,3.5*100%,100*5%) = {excel_payload_calc:.1f}W")

    # Add an endurance calculation breakdown
    print("\nEndurance calculation breakdown:")
    net_power = h33_planner.calculate_net_power_draw()
    available_battery_energy = (h33_planner.starting_soc - h33_planner.mission_cancel_soc) * h33_planner.battery_capacity_wh
    available_generator_energy = h33_planner.generator_starting_fill * h33_planner.generator_full_tank_wh * h33_planner.generator_efficiency
    total_available_energy = available_battery_energy + available_generator_energy
    print(f"Net power draw: {net_power:.1f}W")
    print(f"Available battery energy: ({h33_planner.starting_soc} - {h33_planner.mission_cancel_soc}) * {h33_planner.battery_capacity_wh} = {available_battery_energy:.1f}Wh")
    print(f"Available generator energy: {h33_planner.generator_starting_fill} * {h33_planner.generator_full_tank_wh} * {h33_planner.generator_efficiency} = {available_generator_energy:.1f}Wh")
    print(f"Total available energy: {total_available_energy:.1f}Wh")
    if net_power < 0:
        endurance_hours = total_available_energy / abs(net_power)
        endurance_days = endurance_hours / 24
        print(f"Endurance hours: {total_available_energy:.1f}Wh / {abs(net_power):.1f}W = {endurance_hours:.1f}h")
        print(f"Endurance days: {endurance_hours:.1f}h / 24 = {endurance_days:.1f} days")
        print(f"Excel endurance days: {excel_h33_values['Mission endurance (days)']} days")
    
    print("\n## Identified Issues and Potential Solutions")
    # Solar calculation is slightly different
    solar_calc = h33_planner.solar_nominal_w * h33_planner.daily_ghi * h33_planner.solar_derating
    print(f"1. Solar calculation discrepancy:")
    print(f"   Python: {h33_planner.solar_nominal_w} * {h33_planner.daily_ghi} * {h33_planner.solar_derating} = {solar_calc:.1f}Wh")
    print(f"   Excel: 1529Wh")
    print(f"   Difference: {solar_calc - excel_h33_values['Daily solar input (Wh)']:.1f}Wh ({(solar_calc - excel_h33_values['Daily solar input (Wh)']) / excel_h33_values['Daily solar input (Wh)'] * 100:.1f}%)")
    print(f"   Potential cause: Excel might be using a slightly different formula or rounding differently.")
    
    # Endurance calculation discrepancy
    if net_power < 0:
        endurance_hours = total_available_energy / abs(net_power)
        endurance_days = endurance_hours / 24
        print(f"\n2. Endurance calculation discrepancy:")
        print(f"   Python endurance days: {endurance_days:.1f}")
        print(f"   Excel endurance days: {excel_h33_values['Mission endurance (days)']}")
        print(f"   Difference: {endurance_days - excel_h33_values['Mission endurance (days)']:.1f} days ({(endurance_days - excel_h33_values['Mission endurance (days)']) / excel_h33_values['Mission endurance (days)'] * 100:.1f}%)")
        print(f"   Potential cause: The net power draw calculation differs slightly, which has a significant impact on the endurance calculation.")

    # Mission range discrepancy
    if net_power < 0:
        mission_range = endurance_days * (1 - h33_planner.station_keep_percent) * h33_planner.average_speed * 24
        print(f"\n3. Mission range discrepancy:")
        print(f"   Python mission range: {mission_range:.1f} nm")
        print(f"   Excel mission range: {excel_h33_values['Mission range (nautical miles)']} nm")
        percent_diff = (mission_range - excel_h33_values['Mission range (nautical miles)']) / excel_h33_values['Mission range (nautical miles)'] * 100
        print(f"   Difference: {mission_range - excel_h33_values['Mission range (nautical miles)']:.1f} nm ({percent_diff:.1f}%)")
        print(f"   Potential cause: Since mission range depends on endurance days, the discrepancy propagates from the endurance calculation.")

if __name__ == "__main__":
    main()
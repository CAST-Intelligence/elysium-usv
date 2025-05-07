#!/usr/bin/env python3
"""
Test compression ratio of binary files using different algorithms.
Compares compression of both original binary files and converted text format.
Includes timing measurements for each operation.
All compression ratios are calculated relative to the original binary file size.
"""
import os
import sys
import zlib
import bz2
import lzma
import time
import subprocess
from pathlib import Path
from collections import defaultdict

# Try importing the additional compression libraries
try:
    import zstandard as zstd
except ImportError:
    print("Warning: zstandard module not found. Zstd compression will be skipped.")
    zstd = None

try:
    import lz4.frame
except ImportError:
    print("Warning: lz4.frame module not found. LZ4 compression will be skipped.")
    lz4 = None

try:
    import brotli
except ImportError:
    print("Warning: brotli module not found. Brotli compression will be skipped.")
    brotli = None

def compress_with_timing(data, compress_func):
    """Compress data and measure time."""
    start_time = time.time()
    compressed = compress_func(data)
    elapsed_time = time.time() - start_time
    return compressed, elapsed_time

def convert_to_text(binary_file):
    """Convert binary file to text using sbgBasicLogger."""
    try:
        start_time = time.time()
        result = subprocess.run(
            ["sbgBasicLogger", "-i", str(binary_file), "-p"],
            capture_output=True,
            text=True,
            check=True
        )
        elapsed_time = time.time() - start_time
        return result.stdout.encode('utf-8'), elapsed_time  # Return as bytes for consistency
    except subprocess.CalledProcessError as e:
        print(f"Error converting {binary_file}: {e}")
        return None, 0
    except FileNotFoundError:
        print("Error: sbgBasicLogger command not found")
        sys.exit(1)

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <directory>")
        sys.exit(1)
    
    directory = Path(sys.argv[1])
    if not directory.is_dir():
        print(f"Error: {directory} is not a directory")
        sys.exit(1)
    
    # Get all non-md5 files
    files = [f for f in directory.glob('*') if f.is_file() and not f.name.endswith('.md5')]
    
    if not files:
        print(f"No non-md5 files found in {directory}")
        sys.exit(1)
    
    print(f"Testing compression on {len(files)} files in {directory}\n")
    
    # Define compression algorithms
    compression_algos = []
    
    # Add core algorithms (always available)
    compression_algos.extend([
        ('zlib', lambda d: zlib.compress(d, 9)),
        ('bz2', lambda d: bz2.compress(d, 9)),
        ('lzma', lambda d: lzma.compress(d, preset=9))
    ])
    
    # Add optional algorithms if available
    if zstd:
        compression_algos.append(('zstd', lambda d: zstd.compress(d, 22)))  # Level 22 is high compression
    if lz4:
        compression_algos.append(('lz4', lambda d: lz4.frame.compress(d, compression_level=16)))  # Max compression
    if brotli:
        compression_algos.append(('brotli', lambda d: brotli.compress(d, quality=11)))  # Max quality
    
    # For summary statistics
    formats = ["binary", "text"]
    algorithms = [algo[0] for algo in compression_algos]
    
    # Format: {format: {algorithm: {metric: [values]}}}
    all_stats = {
        fmt: {
            alg: {"ratios": [], "times": [], "sizes": []} 
            for alg in algorithms
        } 
        for fmt in formats
    }
    
    conversion_stats = {"times": [], "ratios": []}
    
    # Process each file
    for file_path in files:
        # Process binary format
        with open(file_path, 'rb') as f:
            binary_data = f.read()
        
        binary_size = len(binary_data)
        binary_size_kb = binary_size / 1024
        
        # Process text format
        text_data, conversion_time = convert_to_text(file_path)
        
        if text_data:
            text_size = len(text_data)
            text_size_kb = text_size / 1024
            text_to_binary_ratio = text_size / binary_size
            
            conversion_stats["times"].append(conversion_time)
            conversion_stats["ratios"].append(text_to_binary_ratio)
            
            # Print file information
            print(f"\nFile: {file_path.name}")
            print(f"Binary size: {binary_size_kb:.2f} KB, Text size: {text_size_kb:.2f} KB")
            print(f"Text/Binary size ratio: {text_to_binary_ratio:.4f}, Text conversion time: {conversion_time:.4f} seconds")
            
            # Print combined table header
            print("-" * 80)
            print(f"{'Format':<10} {'Algorithm':<10} {'Compressed (KB)':<15} {'Ratio to Orig':<15} {'Time (s)':<10}")
            print("-" * 80)
            
            # Process binary compression
            for name, compress_func in compression_algos:
                compressed, elapsed_time = compress_with_timing(binary_data, compress_func)
                comp_size = len(compressed)
                comp_size_kb = comp_size / 1024
                ratio = comp_size / binary_size  # Ratio to original binary
                
                print(f"{'binary':<10} {name:<10} {comp_size_kb:<15.2f} {ratio:<15.4f} {elapsed_time:<10.4f}")
                all_stats["binary"][name]["ratios"].append(ratio)
                all_stats["binary"][name]["times"].append(elapsed_time)
                all_stats["binary"][name]["sizes"].append(comp_size)
            
            # Process text compression
            for name, compress_func in compression_algos:
                compressed, elapsed_time = compress_with_timing(text_data, compress_func)
                comp_size = len(compressed)
                comp_size_kb = comp_size / 1024
                ratio = comp_size / binary_size  # Ratio to original binary size
                total_time = elapsed_time + conversion_time  # Include conversion time
                
                print(f"{'text':<10} {name:<10} {comp_size_kb:<15.2f} {ratio:<15.4f} {total_time:<10.4f}")
                all_stats["text"][name]["ratios"].append(ratio)
                all_stats["text"][name]["times"].append(elapsed_time)  # Store compression time only
                all_stats["text"][name]["sizes"].append(comp_size)
    
    # Print summary statistics
    print("\n\n" + "=" * 80)
    print("SUMMARY STATISTICS")
    print("=" * 80)
    print(f"{'Format':<10} {'Algorithm':<10} {'Avg Ratio':<12} {'Min Ratio':<12} {'Max Ratio':<12} {'Avg Time (s)':<12}")
    print("-" * 80)
    
    for fmt in formats:
        for alg in algorithms:
            if alg not in all_stats[fmt]:
                continue
                
            ratios = all_stats[fmt][alg]["ratios"]
            times = all_stats[fmt][alg]["times"]
            
            if ratios:
                avg_ratio = sum(ratios) / len(ratios)
                min_ratio = min(ratios)
                max_ratio = max(ratios)
                
                avg_time = sum(times) / len(times)
                if fmt == "text":
                    # Add average conversion time for text format
                    avg_conv_time = sum(conversion_stats["times"]) / len(conversion_stats["times"])
                    avg_time += avg_conv_time
                
                print(f"{fmt:<10} {alg:<10} {avg_ratio:<12.4f} {min_ratio:<12.4f} {max_ratio:<12.4f} {avg_time:<12.4f}")
    
    # Print text conversion summary
    if conversion_stats["times"]:
        avg_time = sum(conversion_stats["times"]) / len(conversion_stats["times"])
        avg_ratio = sum(conversion_stats["ratios"]) / len(conversion_stats["ratios"])
        
        print("\n" + "-" * 60)
        print("TEXT CONVERSION SUMMARY")
        print("-" * 60)
        print(f"Average Text/Binary size ratio: {avg_ratio:.4f}")
        print(f"Average conversion time: {avg_time:.4f} seconds")
    
    # Calculate overall best compression method relative to original binary
    print("\n" + "-" * 80)
    print("BEST COMPRESSION METHODS (ranked by compression ratio relative to original binary size)")
    print("-" * 80)
    
    all_compression = []
    for fmt in formats:
        for alg in algorithms:
            if alg not in all_stats[fmt]:
                continue
                
            ratios = all_stats[fmt][alg]["ratios"]
            times = all_stats[fmt][alg]["times"]
            
            if ratios:
                avg_ratio = sum(ratios) / len(ratios)
                avg_comp_time = sum(times) / len(times)
                
                # For text format, include conversion time in the total
                avg_total_time = avg_comp_time
                if fmt == "text" and conversion_stats["times"]:
                    avg_total_time += sum(conversion_stats["times"]) / len(conversion_stats["times"])
                
                all_compression.append((fmt, alg, avg_ratio, avg_total_time))
    
    # Sort by compression ratio (best first)
    all_compression.sort(key=lambda x: x[2])
    
    print(f"{'Rank':<6} {'Format':<10} {'Algorithm':<10} {'Avg Ratio':<12} {'Total Time (s)':<15}")
    print("-" * 80)
    for i, (fmt, alg, ratio, time) in enumerate(all_compression[:10], 1):
        print(f"{i:<6} {fmt:<10} {alg:<10} {ratio:<12.4f} {time:<15.4f}")

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
Script untuk cek list agent & model tanpa pakai token AI.
Baca langsung dari openclaw.json, parse lokal, zero token cost.
"""

import json
import os
import sys
from pathlib import Path

def read_openclaw_config():
    """Baca config dari openclaw.json"""
    config_path = Path("/root/.openclaw/openclaw.json")
    if not config_path.exists():
        print("❌ openclaw.json tidak ditemukan!")
        return None
    
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        print(f"❌ Error parsing JSON: {e}")
        return None
    except Exception as e:
        print(f"❌ Error membaca file: {e}")
        return None

def get_agents_list(config):
    """Ambil list agent dari config"""
    agents = config.get('agents', {}).get('list', [])
    if not agents:
        print("⚠️ Tidak ada agent ditemukan di config")
        return []
    return agents

def get_global_default_model(config):
    """Ambil global default model"""
    defaults = config.get('agents', {}).get('defaults', {})
    model_config = defaults.get('model', {})
    primary = model_config.get('primary', 'tidak dikonfigurasi')
    fallbacks = model_config.get('fallbacks', [])
    return primary, fallbacks

def format_agent_info(agent):
    """Format info agent untuk display"""
    agent_id = agent.get('id', 'unknown')
    model_config = agent.get('model', {})
    
    # Primary model
    primary = model_config.get('primary', 'global')
    
    # Fallbacks
    fallbacks = model_config.get('fallbacks', [])
    fallback_count = len(fallbacks)
    fallback_str = ', '.join(fallbacks[:2])  # Tampilkan max 2
    if fallback_count > 2:
        fallback_str += f" (+{fallback_count-2} lainnya)"
    
    # Tentukan provider
    provider = 'unknown'
    if '/' in primary:
        provider = primary.split('/')[0]
    elif primary == 'global':
        provider = '(default)'
    
    # Tentukan role berdasarkan agent ID
    roles = {
        'agent1': 'Santa - Chat/analisis (input murah)',
        'agent2': 'Generate teks (output murah)',
        'agent3': 'Reasoning/analisis data',
        'agent4': 'Coding/teknis (powerful)',
        'agent5': 'Backup/monitoring (cepat & murah)',
        'agent6': 'Backup variasi',
        'agent7': 'Backup variasi',
        'agent8': 'Backup coding',
        'main': 'Default fallback'
    }
    role = roles.get(agent_id, 'Specialized agent')
    
    return {
        'id': agent_id,
        'primary': primary,
        'provider': provider,
        'fallbacks': fallbacks,
        'fallback_count': fallback_count,
        'fallback_str': fallback_str,
        'role': role
    }

def display_agents_table(agents_info):
    """Display agents dalam format tabel"""
    print("\n" + "="*80)
    print("DAFTAR AGENT & MODEL (Zero Token Cost)")
    print("="*80)
    print(f"{'Agent':<10} {'Model Primary':<30} {'Provider':<15} {'Role':<40}")
    print("-"*80)
    
    for info in agents_info:
        print(f"{info['id']:<10} {info['primary']:<30} {info['provider']:<15} {info['role']:<40}")
    
    print("-"*80)
    print(f"Total: {len(agents_info)} agent")
    print("="*80)

def display_detailed_info(agents_info, global_primary, global_fallbacks):
    """Display info detail"""
    print("\n📊 DETAIL KONFIGURASI")
    print("-"*50)
    
    # Global default
    print(f"🌐 Global Default Model: {global_primary}")
    if global_fallbacks:
        print(f"   Fallbacks: {', '.join(global_fallbacks)}")
    
    # Per agent detail
    print("\n🔧 Per Agent Configuration:")
    for info in agents_info:
        print(f"\n  {info['id']}:")
        print(f"    • Model: {info['primary']}")
        print(f"    • Provider: {info['provider']}")
        print(f"    • Role: {info['role']}")
        if info['fallbacks']:
            print(f"    • Fallbacks ({info['fallback_count']}): {info['fallback_str']}")
    
    # Statistik
    print("\n📈 STATISTIK:")
    providers = set(info['provider'] for info in agents_info)
    custom_agents = [info for info in agents_info if info['primary'] != 'global']
    total_fallbacks = sum(info['fallback_count'] for info in agents_info)
    
    print(f"  • Total Agent: {len(agents_info)}")
    print(f"  • Agent dengan Model Custom: {len(custom_agents)}")
    print(f"  • Provider Berbeda: {len(providers)} ({', '.join(sorted(providers))})")
    print(f"  • Total Fallback Models: {total_fallbacks}")
    print(f"  • Rata-rata Fallback per Agent: {total_fallbacks/len(agents_info):.1f}")

def main():
    """Main function"""
    print("🔍 Membaca konfigurasi OpenClaw...")
    
    # Baca config
    config = read_openclaw_config()
    if not config:
        sys.exit(1)
    
    # Ambil data
    agents = get_agents_list(config)
    global_primary, global_fallbacks = get_global_default_model(config)
    
    if not agents:
        print("❌ Tidak ada agent ditemukan")
        sys.exit(1)
    
    # Process agent info
    agents_info = []
    for agent in agents:
        agents_info.append(format_agent_info(agent))
    
    # Sort by agent ID
    agents_info.sort(key=lambda x: x['id'])
    
    # Display
    display_agents_table(agents_info)
    display_detailed_info(agents_info, global_primary, global_fallbacks)
    
    # Routing info
    print("\n🔄 ROUTING RULES (sesuai AGENTS.md):")
    print("  • Chat/Q&A/analisis → agent1 (Gemini, input murah)")
    print("  • Generate teks panjang → agent2 (DeepSeek, output murah)")
    print("  • Analisis data/riset → agent3 (GLM-5)")
    print("  • Coding/infrastruktur → agent4 (Claude Opus)")
    print("  • Monitoring/backup → agent5 (Claude Haiku)")
    print("  • Backup variasi → agent6-8 (Qwen models)")
    
    print("\n✅ Script selesai. **Zero token used!** 🎉")

if __name__ == "__main__":
    main()
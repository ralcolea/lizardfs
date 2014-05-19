#pragma once

#include "config.h"

#include "common/chunk_type_with_address.h"
#include "common/packet.h"
#include "common/serialization_macros.h"

LIZARDFS_DEFINE_PACKET_SERIALIZATION(
		matocs, setVersion, LIZ_MATOCS_SET_VERSION, 0,
		uint64_t,  chunkId,
		ChunkType, chunkType,
		uint32_t,  chunkVersion,
		uint32_t,  newVersion)

LIZARDFS_DEFINE_PACKET_SERIALIZATION(
		matocs, deleteChunk, LIZ_MATOCS_DELETE_CHUNK, 0,
		uint64_t,  chunkId,
		ChunkType, chunkType,
		uint32_t,  chunkVersion)

LIZARDFS_DEFINE_PACKET_SERIALIZATION(
		matocs, createChunk, LIZ_MATOCS_CREATE_CHUNK, 0,
		uint64_t,  chunkId,
		ChunkType, chunkType,
		uint32_t,  chunkVersion)

LIZARDFS_DEFINE_PACKET_SERIALIZATION(
		matocs, truncateChunk, LIZ_MATOCS_TRUNCATE, 0,
		uint64_t,  chunkId,
		ChunkType, chunkType,
		uint32_t,  length,
		uint32_t,  newVersion,
		uint32_t,  oldVersion)

LIZARDFS_DEFINE_PACKET_SERIALIZATION(
		matocs, replicate, LIZ_MATOCS_REPLICATE, 0,
		uint64_t,  chunkId,
		uint32_t,  chunkVersion,
		ChunkType, chunkType,
		std::vector<ChunkTypeWithAddress>, sources)

namespace matocs {
namespace replicate {
inline void deserializePartial(const std::vector<uint8_t>& source,
		uint64_t& chunkId, uint32_t& chunkVersion, ChunkType& chunkType, const uint8_t*& sources) {
	verifyPacketVersionNoHeader(source, 0);
	deserializeAllPacketDataNoHeader(source, chunkId, chunkVersion, chunkType, sources);
}
} // namespace replicate
} // namespace matocs

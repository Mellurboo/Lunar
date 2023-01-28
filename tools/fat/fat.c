#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef uint8_t bool;
#define true 1
#define false 0

typedef struct 
{
    uint8_t BootJumpInstruction[3];
    uint8_t OemIdentifier[8];
    uint16_t BytesPerSector;
    uint8_t SectorsPerCluster;
    uint16_t ReservedSectors;
    uint8_t FatCount;
    uint16_t DirEntryCount;
    uint16_t TotalSectors;
    uint8_t MediaDescriptorType;
    uint16_t SectorsPerFat;
    uint16_t SectorsPerTrack;
    uint16_t Heads;
    uint32_t HiddenSectors;
    uint32_t LargeSectorCount;

    // extended boot record
    uint8_t DriveNumber;
    uint8_t _Reserved;
    uint8_t Signature;
    uint32_t VolumeId;          // serial number, value doesn't matter
    uint8_t VolumeLabel[11];    // 11 bytes, padded with spaces
    uint8_t SystemId[8];

    // ... we don't care about code ...

} __attribute__((packed)) BootSector;

typedef struct 
{
    uint8_t Name[11];
    uint8_t Attributes;
    uint8_t _Reserved;
    uint8_t CreatedTimeTenths;
    uint16_t CreatedTime;
    uint16_t CreatedDate;
    uint16_t AccessedDate;
    uint16_t FirstClusterHigh;
    uint16_t ModifiedTime;
    uint16_t ModifiedDate;
    uint16_t FirstClusterLow;
    uint32_t Size;
} __attribute__((packed)) DirectoryEntry;


BootSector globalBootSector;
uint8_t* globalFat = NULL;
DirectoryEntry* globalRootDir = NULL;
uint32_t globalRootDirEnd;


bool readBootSector(FILE* disk)
{
    return fread(&globalBootSector, sizeof(globalBootSector), 1, disk) > 0;
}

bool readSectors(FILE* disk, uint32_t lba, uint32_t count, void* bufferOut)
{
    bool ok = true;
    ok = ok && (fseek(disk, lba * globalBootSector.BytesPerSector, SEEK_SET) == 0);
    ok = ok && (fread(bufferOut, globalBootSector.BytesPerSector, count, disk) == count);
    return ok;
}

bool readFat(FILE* disk)
{
    globalFat = (uint8_t*) malloc(globalBootSector.SectorsPerFat * globalBootSector.BytesPerSector);
    return readSectors(disk, globalBootSector.ReservedSectors, globalBootSector.SectorsPerFat, globalFat);
}

bool readRootDirectory(FILE* disk)
{
    uint32_t lba = globalBootSector.ReservedSectors + globalBootSector.SectorsPerFat * globalBootSector.FatCount;
    uint32_t size = sizeof(DirectoryEntry) * globalBootSector.DirEntryCount;
    uint32_t sectors = (size / globalBootSector.BytesPerSector);
    if (size % globalBootSector.BytesPerSector > 0)
        sectors++;

    globalRootDirEnd = lba + sectors;
    globalRootDir = (DirectoryEntry*) malloc(sectors * globalBootSector.BytesPerSector);
    return readSectors(disk, lba, sectors, globalRootDir);
}

DirectoryEntry* findFile(const char* name)
{
    for (uint32_t i = 0; i < globalBootSector.DirEntryCount; i++)
    {
        if (memcmp(name, globalRootDir[i].Name, 11) == 0)
            return &globalRootDir[i];
    }

    return NULL;
}

bool readFile(DirectoryEntry* fileEntry, FILE* disk, uint8_t* outputBuffer)
{
    bool ok = true;
    uint16_t currentCluster = fileEntry->FirstClusterLow;

    do {
        uint32_t lba = globalRootDirEnd + (currentCluster - 2) * globalBootSector.SectorsPerCluster;
        ok = ok && readSectors(disk, lba, globalBootSector.SectorsPerCluster, outputBuffer);
        outputBuffer += globalBootSector.SectorsPerCluster * globalBootSector.BytesPerSector;

        uint32_t fatIndex = currentCluster * 3 / 2;
        if (currentCluster % 2 == 0)
            currentCluster = (*(uint16_t*)(globalFat + fatIndex)) & 0x0FFF;
        else
            currentCluster = (*(uint16_t*)(globalFat + fatIndex)) >> 4;

    } while (ok && currentCluster < 0x0FF8);

    return ok;
}

int main(int argc, char** argv)
{
    if (argc < 3) {
        printf("Syntax: %s <.img> <file name>\n", argv[0]);
        return -1;
    }

    FILE* disk = fopen(argv[1], "rb");
    if (!disk) {
        fprintf(stderr, "Cannot open disk image %s!\n", argv[1]);
        return -1;
    }

    if (!readBootSector(disk)) {
        fprintf(stderr, "Could not read boot sector, hardware issue?\n");
        return -2;
    }

    if (!readFat(disk)) {
        fprintf(stderr, "Could not read FAT!\n");
        free(globalFat);
        return -3;
    }

    if (!readRootDirectory(disk)) {
        fprintf(stderr, "Could not read FAT!\n");
        free(globalFat);
        free(globalRootDir);
        return -4;
    }

    DirectoryEntry* fileEntry = findFile(argv[2]);
    if (!fileEntry) {
        fprintf(stderr, "Could not find file %s!\n", argv[2]);
        free(globalFat);
        free(globalRootDir);
        return -5;
    }

    uint8_t* buffer = (uint8_t*) malloc(fileEntry->Size + globalBootSector.BytesPerSector);
    if (!readFile(fileEntry, disk, buffer)) {
        fprintf(stderr, "Could not read file %s!\n", argv[2]);
        free(globalFat);
        free(globalRootDir);
        free(buffer);
        return -5;
    }

    for (size_t i = 0; i < fileEntry->Size; i++)
    {
        if (isprint(buffer[i])) fputc(buffer[i], stdout);
        else printf("<%02x>", buffer[i]);
    }
    printf("\n");

    free(buffer);
    free(globalFat);
    free(globalRootDir);
    return 0;
}
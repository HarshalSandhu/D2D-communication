# D2D Communication Setup Using SDR (Adalm Plutos)

This repository contains the implementation of the **Setup Phase of Device-to-Device (D2D) Communication** using **Software Defined Radios (SDR)**, specifically with **Adalm Plutos**. The project is aimed at establishing a synchronized communication system between multiple devices using various signal processing techniques such as beaconing, RTS/CTS (Request to Send/Clear to Send), device discovery, and validation.

## Table of Contents

- [Project Overview](#project-overview)
- [Installation](#installation)
- [Hardware Requirements](#hardware-requirements)
- [Files and Usage](#files-and-usage)
- [Steps to Run](#steps-to-run)
- [Extending for More Devices](#extending-for-more-devices)
- [Contributing](#contributing)
- [License](#license)

## Project Overview

This implementation focuses on the **Setup Phase** of D2D communication, involving:
- Beaconing and device discovery
- Device validation (based on signal power and distance)
- RTS (Request to Send), CTS (Clear to Send)
- Data sharing between multiple devices

The primary goal of the setup phase is to synchronize the sending and receiving of signals across different devices, ensuring accurate communication between them.

## Installation

### Required Tool Packages

Make sure you have the following tools and packages installed on your system before running the code:
1. **MATLAB**
2. **Communications Toolbox** (for signal processing)
3. **Support Package for Adalm Pluto Radio** (to interface with the SDR)

For installing the Adalm Pluto support package in MATLAB:
```bash
>> plutoradioSetup
```

### Hardware Requirements

- **Adalm Pluto SDRs** for each device
- Two or more **PCs** (each connected to an SDR)
- Stable network connection for synchronization

## Files and Usage

The repository consists of several files, but only two main files are critical for running the system:
1. **Device1.m**: Script to be run on the first device (PC 1).
2. **Device2.m**: Script to be run on the second device (PC 2).

Other support files handle various functions such as frame handling, signal processing, and device discovery.

### Main Files Description:
- **Device1.m**: Handles the sending of initial beaconing signals and receiving responses.
- **Device2.m**: Receives the beaconing signals and sends an acknowledgment, followed by RTS/CTS and data sharing.

## Steps to Run

1. Use two separate PCs and copy all the files to the **same directory** on both systems.
2. Open **Device1.m** on PC 1 and **Device2.m** on PC 2.
3. Ensure both MATLAB instances are properly connected to their respective SDRs.
4. **Run both files at the same time** to synchronize the communication process.
   - The output from **Device1** will be printed in the MATLAB **Script Window**.
   - The output from **Device2** will be printed in the **Terminal Window**.
   
   This process ensures proper synchronization of sending and receiving signals.

## Extending for More Devices

To add another device to the system:
1. Copy the code from **Device2.m** and create a new file (e.g., **Device3.m**).
2. Adjust the **delays** in the sending and receiving processes to ensure correct synchronization between multiple devices.
3. Repeat the steps to synchronize this new device in the setup phase.

## Contributing

Contributions are welcome! Please fork the repository, create a new branch, and submit a pull request with your changes.

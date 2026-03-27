from setuptools import setup, find_packages

setup(
    name='multiqc-proteinfold',
    version='0.1.0',
    author='Keiran Rowell',
    author_email='k.rowell@unsw.edu.au',
    description='MultiQC plugin for proteinfold pipeline metric tsv outputs',
    url='https://github.com/nf-core/proteinfold',
    packages=find_packages(),
    include_package_data=True,
    entry_points={
        'multiqc.modules.v1': [
            'proteinfold = multiqc_proteinfold.proteinfold:MultiqcModule',
        ],
    },
    install_requires=[
        'multiqc>=1.15',
        'pandas',
    ],
    classifiers=[
        'Development Status :: 4 - Beta',
        'Intended Audience :: Science/Research',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Python :: 3',
    ],
    python_requires='>=3.8',
)
